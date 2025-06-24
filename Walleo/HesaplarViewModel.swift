import SwiftUI
import SwiftData

@MainActor
@Observable
class HesaplarViewModel {
    var modelContext: ModelContext
    var gosterilecekHesaplar: [GosterilecekHesap] = []

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(hesaplamalariTetikle(notification:)),
            name: .transactionsDidChange,
            object: nil
        )
    }

    @objc func hesaplamalariTetikle(notification: Notification) {
        // Gelen bildirimin içinde yeni payload'ımız var mı diye kontrol et
        guard let payload = notification.userInfo?["payload"] as? TransactionChangePayload else {
            // Eğer yoksa (eski sistem veya genel bir bildirim), her şeyi yeniden hesapla
            Task { await hesaplamalariYap() }
            return
        }
        
        // Mevcut hesaplarımızın ID'lerini bir set olarak alalım
        let currentAccountIDs = Set(gosterilecekHesaplar.map { $0.id })
        
        // Etkilenen hesaplardan en az biri benim listemde var mı?
        let isRelevantChange = !Set(payload.affectedAccountIDs).isDisjoint(with: currentAccountIDs)
        
        if isRelevantChange {
            // Evet, değişiklik beni ilgilendiriyor. Sadece etkilenen hesapları güncelle.
            Task { await guncelBakiyeHesapla(for: payload.affectedAccountIDs) }
        } else {
            // Hayır, bu değişiklik benim yönettiğim hesaplarla ilgili değil. Hiçbir şey yapma.
            print("HesaplarViewModel: Değişiklik fark edildi ancak ilgili hesap bulunmadığı için güncelleme yapılmadı.")
        }
    }

    func hesaplamalariYap() async {
        do {
            let hesaplar = try modelContext.fetch(FetchDescriptor<Hesap>(sortBy: [SortDescriptor(\.olusturmaTarihi)]))
            let islemler = try modelContext.fetch(FetchDescriptor<Islem>())
            
            var netDegisimler: [UUID: Double] = [:]
            for islem in islemler {
                guard let hesapID = islem.hesap?.id else { continue }
                let tutarDegisimi = islem.tur == .gelir ? islem.tutar : -islem.tutar
                netDegisimler[hesapID, default: 0] += tutarDegisimi
            }
            
            var yeniListe: [GosterilecekHesap] = []
            for hesap in hesaplar {
                let netDegisim = netDegisimler[hesap.id] ?? 0
                let guncelBakiye = hesap.baslangicBakiyesi + netDegisim
                var gosterilecekHesap = GosterilecekHesap(hesap: hesap, guncelBakiye: guncelBakiye)
                
                switch hesap.detay {
                case .krediKarti(let limit, _, _):
                    let harcamalarToplami = netDegisim < 0 ? abs(netDegisim) : 0
                    let guncelBorc = abs(hesap.baslangicBakiyesi) + harcamalarToplami
                    let kullanilabilirLimit = max(0, limit - guncelBorc)
                    gosterilecekHesap.krediKartiDetay = .init(guncelBorc: guncelBorc, kullanilabilirLimit: kullanilabilirLimit)
                    gosterilecekHesap.guncelBakiye = -guncelBorc
                    
                case .kredi(_, _, _, let taksitSayisi, _, let taksitler):
                    let odenenTaksitSayisi = taksitler.filter { $0.odendiMi }.count
                    gosterilecekHesap.krediDetay = .init(kalanTaksitSayisi: taksitSayisi - odenenTaksitSayisi, odenenTaksitSayisi: odenenTaksitSayisi)
                
                case .cuzdan:
                    break
                }
                yeniListe.append(gosterilecekHesap)
            }
            self.gosterilecekHesaplar = yeniListe
            
        } catch {
            print("Hesap ViewModel hesaplama hatası: \(error)")
        }
    }

    private func guncelBakiyeHesapla(for accountIDs: [UUID]) async {
        let uniqueIDs = Set(accountIDs)
        
        for accountID in uniqueIDs {
            guard let index = gosterilecekHesaplar.firstIndex(where: { $0.hesap.id == accountID }) else {
                await hesaplamalariYap()
                return
            }
            
            let hesap = gosterilecekHesaplar[index].hesap
            
            do {
                let predicate = #Predicate<Islem> { $0.hesap?.id == accountID }
                let descriptor = FetchDescriptor<Islem>(predicate: predicate)
                let islemler = try modelContext.fetch(descriptor)
                
                let netDegisim = islemler.reduce(0) { $0 + ($1.tur == .gelir ? $1.tutar : -$1.tutar) }
                let guncelBakiye = hesap.baslangicBakiyesi + netDegisim
                
                gosterilecekHesaplar[index].guncelBakiye = guncelBakiye
                
                // --- DÜZELTME BURADA ---
                // if case'i 3 parametreyi de karşılayacak şekilde güncelliyoruz.
                if case .krediKarti(let limit, _, _) = hesap.detay {
                    let harcamalarToplami = islemler.filter { $0.tur == .gider }.reduce(0) { $0 + $1.tutar }
                    let guncelBorc = abs(hesap.baslangicBakiyesi) + harcamalarToplami
                    let kullanilabilirLimit = max(0, limit - guncelBorc)
                    gosterilecekHesaplar[index].krediKartiDetay = .init(guncelBorc: guncelBorc, kullanilabilirLimit: kullanilabilirLimit)
                } else if case .kredi(_, _, _, let taksitSayisi, _, let taksitler) = hesap.detay {
                    let odenenTaksitSayisi = taksitler.filter { $0.odendiMi }.count
                    gosterilecekHesaplar[index].krediDetay = .init(kalanTaksitSayisi: taksitSayisi - odenenTaksitSayisi, odenenTaksitSayisi: odenenTaksitSayisi)
                }
                
            } catch {
                print("Hedefe yönelik hesaplama sırasında hata: \(error)")
            }
        }
    }
    
    func hesabiSil(hesap: Hesap) {
        if let iliskiliIslemler = hesap.islemler {
            for islem in iliskiliIslemler {
                islem.hesap = nil
            }
        }
        modelContext.delete(hesap)
        NotificationCenter.default.post(name: .transactionsDidChange, object: nil)
    }
}
