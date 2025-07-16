// Walleo/Features/Accounts/HesaplarViewModel.swift

import SwiftUI
import SwiftData

@MainActor
@Observable
class HesaplarViewModel {
    var modelContext: ModelContext
    
    // ViewModel artık doğrudan bu üç listeyi yönetiyor
    var cuzdanHesaplari: [GosterilecekHesap] = []
    var krediKartiHesaplari: [GosterilecekHesap] = []
    var krediHesaplari: [GosterilecekHesap] = []
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(hesaplamalariTetikle), // Fonksiyon adı daha genel hale getirildi
            name: .transactionsDidChange,
            object: nil
        )
    }
    
    // Herhangi bir veri değişikliğinde bu fonksiyon tetiklenir.
    @objc func hesaplamalariTetikle() {
        Task { await hesaplamalariYap() }
    }
    
    // Bu ana fonksiyon, tüm hesapları ve bakiyeleri sıfırdan hesaplayıp doğru listelere atar.
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
            
            // Her seferinde listeleri temizle
            var yeniCuzdanlar: [GosterilecekHesap] = []
            var yeniKrediKartlari: [GosterilecekHesap] = []
            var yeniKrediler: [GosterilecekHesap] = []
            
            for hesap in hesaplar {
                let netDegisim = netDegisimler[hesap.id] ?? 0
                let guncelBakiye = hesap.baslangicBakiyesi + netDegisim
                var gosterilecekHesap = GosterilecekHesap(hesap: hesap, guncelBakiye: guncelBakiye)
                
                switch hesap.detay {
                case .cuzdan:
                    yeniCuzdanlar.append(gosterilecekHesap)
                    
                case .krediKarti(let limit, _, _):
                    let harcamalarToplami = netDegisim < 0 ? abs(netDegisim) : 0
                    let guncelBorc = abs(hesap.baslangicBakiyesi) + harcamalarToplami
                    let kullanilabilirLimit = max(0, limit - guncelBorc)
                    gosterilecekHesap.krediKartiDetay = .init(guncelBorc: guncelBorc, kullanilabilirLimit: kullanilabilirLimit)
                    gosterilecekHesap.guncelBakiye = -guncelBorc
                    yeniKrediKartlari.append(gosterilecekHesap)
                    
                case .kredi(_, _, _, let taksitSayisi, _, let taksitler):
                    let odenenTaksitSayisi = taksitler.filter { $0.odendiMi }.count
                    gosterilecekHesap.krediDetay = .init(kalanTaksitSayisi: taksitSayisi - odenenTaksitSayisi, odenenTaksitSayisi: odenenTaksitSayisi)
                    yeniKrediler.append(gosterilecekHesap)
                }
            }
            // Yeni listeleri ata
            self.cuzdanHesaplari = yeniCuzdanlar
            self.krediKartiHesaplari = yeniKrediKartlari
            self.krediHesaplari = yeniKrediler
            
        } catch {
            Logger.log("Hesap ViewModel genel hesaplama hatası: \(error.localizedDescription)", log: Logger.data, type: .error)
        }
    }
    
    // Silme fonksiyonu aynı kalabilir
    func hesabiSil(hesap: Hesap) {
        do {
            if let iliskiliIslemler = hesap.islemler {
                for islem in iliskiliIslemler {
                    islem.hesap = nil
                }
            }
            modelContext.delete(hesap)
            try modelContext.save()
            Task { await hesaplamalariYap() }
            NotificationCenter.default.post(name: .transactionsDidChange, object: nil)
        } catch {
            Logger.log("Hesap silme hatası: \(error)", log: Logger.service, type: .error)
        }
    }
}
