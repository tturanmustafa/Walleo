// Dosya: CuzdanDetayViewModel.swift

import SwiftUI
import SwiftData

@MainActor
@Observable
class CuzdanDetayViewModel {
    var modelContext: ModelContext?
    var hesap: Hesap
    
    var currentDate = Date() {
        didSet {
            // Sadece ay değiştiğinde verileri yenile
            let calendar = Calendar.current
            let oldMonth = calendar.component(.month, from: oldValue)
            let oldYear = calendar.component(.year, from: oldValue)
            let newMonth = calendar.component(.month, from: currentDate)
            let newYear = calendar.component(.year, from: currentDate)
            
            if oldMonth != newMonth || oldYear != newYear {
                islemleriGetir()
                transferleriGetir()
            }
        }
    }
    
    var donemIslemleri: [Islem] = []
    var toplamGelir: Double = 0.0
    var toplamGider: Double = 0.0
    var tumTransferler: [Transfer] = []
    
    init(hesap: Hesap) {
        self.hesap = hesap
    }
    
    func initialize(modelContext: ModelContext) {
        guard self.modelContext == nil else { return }
        
        self.modelContext = modelContext
        islemleriGetir()
        transferleriGetir()
        
        // YENİ: Notification observer'ları sadece bir kez ekle
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(verilerDegisti(_:)),
            name: .transactionsDidChange,
            object: nil
        )
    }
    
    @objc private func verilerDegisti(_ notification: Notification) {
        // Sadece bu hesabı etkileyen değişikliklerde güncelle
        if let payload = notification.userInfo?["payload"] as? TransactionChangePayload {
            let hesapID = hesap.id
            
            // Bu hesapla ilgili bir değişiklik var mı kontrol et
            if payload.affectedAccountIDs.contains(hesapID) {
                islemleriGetir()
                transferleriGetir()
            }
        } else {
            // Payload yoksa varsayılan olarak güncelle
            islemleriGetir()
            transferleriGetir()
        }
    }
    
    func transferleriGetir() {
        guard let modelContext = self.modelContext else { return }
        
        // --- DEĞİŞİKLİK BURADA BAŞLIYOR ---
        // 1. İşlemleri filtrelemek için kullandığımız ay aralığını burada da kullanacağız.
        let calendar = Calendar.current
        guard let monthInterval = calendar.dateInterval(of: .month, for: currentDate) else { return }
        
        let baslangic = monthInterval.start
        let bitis = monthInterval.end
        // --- DEĞİŞİKLİK SONU ---
        
        let hesapID = hesap.id
        
        // YENİ: Önce hafızada olan transferleri kullan
        let gelenTransferler = hesap.gelenTransferler ?? []
        let gidenTransferler = hesap.gidenTransferler ?? []
        
        let tumHafizadakiTransferler = gelenTransferler + gidenTransferler
        let filtreliTransferler = tumHafizadakiTransferler.filter { transfer in
            transfer.tarih >= baslangic && transfer.tarih < bitis
        }.sorted { $0.tarih > $1.tarih }
        
        if !filtreliTransferler.isEmpty {
            self.tumTransferler = filtreliTransferler
        } else {
            // Hafızada yoksa veya boşsa veritabanından çek
            // 2. Predicate'e tarih filtresi ekliyoruz.
            let predicate = #Predicate<Transfer> { transfer in
                (transfer.kaynakHesap?.id == hesapID || transfer.hedefHesap?.id == hesapID) &&
                (transfer.tarih >= baslangic && transfer.tarih < bitis) // <-- EKLENEN SATIR
            }
            
            let descriptor = FetchDescriptor<Transfer>(
                predicate: predicate,
                sortBy: [SortDescriptor(\.tarih, order: .reverse)]
            )
            
            do {
                let transferler = try modelContext.fetch(descriptor)
                self.tumTransferler = transferler
            } catch {
                Logger.log("Transfer verileri çekilirken hata: \(error)", log: Logger.data, type: .error)
            }
        }
    }
    
    private func islemleriGetir() {
        guard let modelContext = self.modelContext else { return }
        
        let calendar = Calendar.current
        guard let monthInterval = calendar.dateInterval(of: .month, for: currentDate) else { return }
        
        let hesapID = hesap.id
        
        // YENİ: Önce hafızada olan işlemleri kullan
        if let hesapIslemleri = hesap.islemler {
            // Hafızada filtreleme yap
            let filtreliIslemler = hesapIslemleri.filter { islem in
                islem.tarih >= monthInterval.start &&
                islem.tarih < monthInterval.end
            }.sorted { $0.tarih > $1.tarih }
            
            self.donemIslemleri = filtreliIslemler
            
            // Toplamları hesapla
            self.toplamGelir = filtreliIslemler.filter { $0.tur == .gelir }.reduce(0) { $0 + $1.tutar }
            self.toplamGider = filtreliIslemler.filter { $0.tur == .gider }.reduce(0) { $0 + $1.tutar }
            
        } else {
            // Eğer hafızada yoksa veritabanından çek
            let predicate = #Predicate<Islem> { islem in
                islem.hesap?.id == hesapID &&
                islem.tarih >= monthInterval.start &&
                islem.tarih < monthInterval.end
            }
            
            let descriptor = FetchDescriptor<Islem>(
                predicate: predicate,
                sortBy: [SortDescriptor(\.tarih, order: .reverse)]
            )
            
            do {
                let islemler = try modelContext.fetch(descriptor)
                self.donemIslemleri = islemler
                
                self.toplamGelir = islemler.filter { $0.tur == .gelir }.reduce(0) { $0 + $1.tutar }
                self.toplamGider = islemler.filter { $0.tur == .gider }.reduce(0) { $0 + $1.tutar }
                
            } catch {
                Logger.log("Cüzdan detay işlemleri çekilirken hata: \(error.localizedDescription)", log: Logger.data, type: .error)
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
