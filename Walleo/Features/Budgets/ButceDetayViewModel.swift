import SwiftUI
import SwiftData

@MainActor
@Observable
class ButceDetayViewModel {
    let butce: Butce
    var modelContainer: ModelContainer?
    
    var gosterilecekButce: GosterilecekButce?
    var donemIslemleri: [Islem] = []
    
    // Performans için cache
    private var lastFetchDate: Date?
    private var cachedTransactions: [Islem]?
    
    init(butce: Butce) {
        self.butce = butce
    }
    
    func deleteButce(context: ModelContext) {
        context.delete(butce)
        do {
            try context.save()
            NotificationCenter.default.post(name: .transactionsDidChange, object: nil)
        } catch {
            Logger.log("Bütçe silme hatası: \(error)", log: Logger.data, type: .error)
        }
    }
    
    /// Bütçe detayları için gerekli tüm verileri çeken ana fonksiyon.
    func fetchData(context: ModelContext) {
        self.modelContainer = context.container
        
        // 5 saniye içinde tekrar fetch yapılmışsa cache'den dön
        if let lastFetch = lastFetchDate,
           Date().timeIntervalSince(lastFetch) < 5.0,
           let cached = cachedTransactions {
            processTransactions(cached)
            return
        }
        
        guard let ayAraligi = Calendar.current.dateInterval(of: .month, for: self.butce.periyot),
              let kategoriIDleri = butce.kategoriler?.map({ $0.id }),
              !kategoriIDleri.isEmpty else {
            self.donemIslemleri = []
            self.gosterilecekButce = GosterilecekButce(butce: self.butce, harcananTutar: 0)
            Logger.log("Bütçe detayı için gerekli veriler eksik", log: Logger.data)
            return
        }
        
        let kategoriIDSet = Set(kategoriIDleri)
        
        do {
            // SwiftData için basit predicate
            let giderTuruRawValue = IslemTuru.gider.rawValue
            let descriptor = FetchDescriptor<Islem>(
                predicate: #Predicate { islem in
                    islem.tarih >= ayAraligi.start &&
                    islem.tarih < ayAraligi.end &&
                    islem.turRawValue == giderTuruRawValue
                },
                sortBy: [SortDescriptor(\.tarih, order: .reverse)]
            )
            
            let tumDonemGiderleri = try context.fetch(descriptor)
            
            // Cache'e kaydet
            cachedTransactions = tumDonemGiderleri
            lastFetchDate = Date()
            
            // İşlemleri işle
            processTransactions(tumDonemGiderleri)
            
            Logger.log("Bütçe detayı yüklendi: \(donemIslemleri.count) işlem bulundu", log: Logger.data)
            
        } catch {
            Logger.log("Bütçe detay verisi çekilirken hata oluştu: \(error.localizedDescription)", log: Logger.data, type: .error)
        }
    }
    
    private func processTransactions(_ transactions: [Islem]) {
        guard let kategoriIDleri = butce.kategoriler?.map({ $0.id }) else { return }
        let kategoriIDSet = Set(kategoriIDleri)
        
        // Memory'de filtreleme (SwiftData CloudKit uyumu için)
        let ilgiliIslemler = transactions.filter { islem in
            guard let kategoriID = islem.kategori?.id else { return false }
            return kategoriIDSet.contains(kategoriID)
        }
        
        self.donemIslemleri = ilgiliIslemler
        
        // Harcanan tutarı hesapla
        let harcananTutar = ilgiliIslemler.reduce(0) { $0 + $1.tutar }
        
        // Devreden tutarı da ekle
        let toplamLimit = butce.limitTutar + butce.devredenGelenTutar
        
        self.gosterilecekButce = GosterilecekButce(
            butce: self.butce,
            harcananTutar: harcananTutar
        )
    }
    
    func deleteSingleTransaction(_ islem: Islem, context: ModelContext) {
        TransactionService.shared.deleteTransaction(islem, in: context)
        
        // Cache'i invalidate et
        cachedTransactions = nil
        lastFetchDate = nil
    }

    /// Tekrarlanan bir işlem serisini arka planda siler.
    func deleteTransactionSeries(_ islem: Islem) async {
        guard let container = modelContainer else { return }
        await TransactionService.shared.deleteSeriesInBackground(
            tekrarID: islem.tekrarID,
            from: container
        )
        
        // Cache'i invalidate et
        cachedTransactions = nil
        lastFetchDate = nil
    }
    
    /// Taksitli bir işlemin tüm serisini siler.
    func deleteInstallmentTransaction(_ islem: Islem, context: ModelContext) {
        TransactionService.shared.deleteTaksitliIslem(islem, in: context)
        
        // Cache'i invalidate et
        cachedTransactions = nil
        lastFetchDate = nil
    }
}
