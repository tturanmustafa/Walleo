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
        
        // Mevcut bildirim dinleyiciniz
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(hesaplamalariTetikle),
            name: .transactionsDidChange,
            object: nil
        )
        
        // --- 🔥 EKLENECEK KOD BURADA 🔥 ---
        // Hesap detayları değiştiğinde de listenin yenilenmesini sağlıyoruz.
        // Bu, yeni hesap eklendiğinde veya mevcut bir hesap düzenlendiğinde tetiklenir.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(hesaplamalariTetikle),
            name: .accountDetailsDidChange, // Doğru bildirimi dinliyoruz
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
            let transferler = try modelContext.fetch(FetchDescriptor<Transfer>()) // YENİ
            
            // İşlem bazlı değişimler
            var netDegisimler: [UUID: Double] = [:]
            for islem in islemler {
                guard let hesapID = islem.hesap?.id else { continue }
                let tutarDegisimi = islem.tur == .gelir ? islem.tutar : -islem.tutar
                netDegisimler[hesapID, default: 0] += tutarDegisimi
            }
            
            // Transfer bazlı değişimler - YENİ
            var transferDegisimleri: [UUID: Double] = [:]
            for transfer in transferler {
                if let kaynakID = transfer.kaynakHesap?.id {
                    transferDegisimleri[kaynakID, default: 0] -= transfer.tutar
                }
                if let hedefID = transfer.hedefHesap?.id {
                    transferDegisimleri[hedefID, default: 0] += transfer.tutar
                }
            }
            
            // Her seferinde listeleri temizle
            var yeniCuzdanlar: [GosterilecekHesap] = []
            var yeniKrediKartlari: [GosterilecekHesap] = []
            var yeniKrediler: [GosterilecekHesap] = []
            
            for hesap in hesaplar {
                let islemDegisimi = netDegisimler[hesap.id] ?? 0
                let transferDegisimi = transferDegisimleri[hesap.id] ?? 0 // YENİ
                let toplamDegisim = islemDegisimi + transferDegisimi // YENİ
                let guncelBakiye = hesap.baslangicBakiyesi + toplamDegisim // GÜNCELLENDİ
                
                var gosterilecekHesap = GosterilecekHesap(hesap: hesap, guncelBakiye: guncelBakiye)
                
                switch hesap.detay {
                case .cuzdan:
                    yeniCuzdanlar.append(gosterilecekHesap)
                    
                case .krediKarti(let limit, _, _):
                    // Kredi kartı için özel hesaplama
                    let initialBorc = abs(hesap.baslangicBakiyesi)
                    let harcamalar = islemler
                        .filter { $0.hesap?.id == hesap.id && $0.tur == .gider }
                        .reduce(0) { $0 + $1.tutar }
                    let odemeler = transferler
                        .filter { $0.hedefHesap?.id == hesap.id }
                        .reduce(0) { $0 + $1.tutar }
                    
                    let guncelBorc = initialBorc + harcamalar - odemeler
                    let kullanilabilirLimit = max(0, limit - guncelBorc)
                    
                    gosterilecekHesap.krediKartiDetay = .init(
                        guncelBorc: guncelBorc,
                        kullanilabilirLimit: kullanilabilirLimit
                    )
                    gosterilecekHesap.guncelBakiye = -guncelBorc
                    yeniKrediKartlari.append(gosterilecekHesap)
                    
                case .kredi(_, _, _, let taksitSayisi, _, let taksitler):
                    let odenenTaksitSayisi = taksitler.filter { $0.odendiMi }.count
                    gosterilecekHesap.krediDetay = .init(
                        kalanTaksitSayisi: taksitSayisi - odenenTaksitSayisi,
                        odenenTaksitSayisi: odenenTaksitSayisi
                    )
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
