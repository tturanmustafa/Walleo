// Dosya Adı: HesaplarViewModel.swift

import SwiftUI
import SwiftData

@MainActor
@Observable
class HesaplarViewModel {
    var modelContext: ModelContext
    var gosterilecekHesaplar: [GosterilecekHesap] = []

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        
        // NotificationCenter dinleyicisi, artık 'notification' nesnesini
        // doğrudan alabilmesi için selector'ü güncellendi.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(hesaplamalariTetikle(notification:)),
            name: .transactionsDidChange,
            object: nil
        )
    }

    // Bu fonksiyon artık akıllı bildirimi işleyebiliyor.
    @objc func hesaplamalariTetikle(notification: Notification) {
        Task {
            // Bildirim içinde bize gönderilen "etkilenen hesap ID'leri" var mı diye kontrol et.
            if let userInfo = notification.userInfo,
               let accountIDs = userInfo["affectedAccountIDs"] as? [UUID],
               !accountIDs.isEmpty {
                // Eğer varsa, sadece o hesapları güncelleyen yeni ve hızlı fonksiyonu çağır.
                await guncelBakiyeHesapla(for: accountIDs)
            } else {
                // Eğer yoksa (genel bir güncelleme veya eski bir bildirim), her ihtimale karşı
                // tüm listeyi yenileyen eski fonksiyonu çalıştır.
                await hesaplamalariYap()
            }
        }
    }

    // Bu fonksiyon artık sadece ilk açılışta veya genel güncellemelerde kullanılacak.
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
                case .krediKarti(let limit, _):
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

    // Yeni ve hedefe yönelik güncelleme fonksiyonu.
    private func guncelBakiyeHesapla(for accountIDs: [UUID]) async {
        let uniqueIDs = Set(accountIDs)
        
        for accountID in uniqueIDs {
            // Güncellenecek hesabı mevcut listeden bul.
            guard let index = gosterilecekHesaplar.firstIndex(where: { $0.hesap.id == accountID }) else {
                // Eğer hesap listede yoksa (yeni eklenmiş olabilir), tüm listeyi yenilemek en güvenlisi.
                await hesaplamalariYap()
                return
            }
            
            let hesap = gosterilecekHesaplar[index].hesap
            
            do {
                // Sadece bu tek hesaba ait işlemleri veritabanından çekiyoruz.
                let predicate = #Predicate<Islem> { $0.hesap?.id == accountID }
                let descriptor = FetchDescriptor<Islem>(predicate: predicate)
                let islemler = try modelContext.fetch(descriptor)
                
                // O tek hesabın bakiyesini yeniden hesapla.
                let netDegisim = islemler.reduce(0) { $0 + ($1.tur == .gelir ? $1.tutar : -$1.tutar) }
                let guncelBakiye = hesap.baslangicBakiyesi + netDegisim
                
                // Listedeki hesabın değerlerini güncelle.
                gosterilecekHesaplar[index].guncelBakiye = guncelBakiye
                
                // Eğer kredi kartı veya krediyse, özel detaylarını da güncelle.
                if case .krediKarti(let limit, _) = hesap.detay {
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
        
        // Hesap silindiğinde tüm listenin yenilenmesi gerekir.
        // Bu yüzden userInfo göndermeden bildirim yolluyoruz.
        NotificationCenter.default.post(name: .transactionsDidChange, object: nil)
    }
}
