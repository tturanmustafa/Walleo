import SwiftUI
import SwiftData

@MainActor
@Observable
class ButceDetayViewModel {
    let butce: Butce
    var modelContainer: ModelContainer? // <-- YENİ: Eklendi
    
    var gosterilecekButce: GosterilecekButce?
    var donemIslemleri: [Islem] = []
    
    init(butce: Butce) {
        self.butce = butce
    }
    
    func deleteButce(context: ModelContext) {
        context.delete(butce)
        try? context.save()
        NotificationCenter.default.post(name: .transactionsDidChange, object: nil)
    }
    
    /// Bütçe detayları için gerekli tüm verileri çeken ana fonksiyon.
    func fetchData(context: ModelContext) {
        self.modelContainer = context.container // <-- YENİ: Container'ı sakla
        guard let ayAraligi = Calendar.current.dateInterval(of: .month, for: self.butce.periyot),
              let kategoriIDleri = butce.kategoriler?.map({ $0.id }), !kategoriIDleri.isEmpty else {
            self.donemIslemleri = []
            self.gosterilecekButce = GosterilecekButce(butce: self.butce, harcananTutar: 0)
            return
        }
        
        // Kategori ID'lerini daha hızlı arama için bir Set'e dönüştür.
        let kategoriIDSet = Set(kategoriIDleri)
        
        do {
            // --- 1. ADIM: BASİT SORGULAMA ---
            // Veritabanından sadece TARİH ve TÜR'e göre basit bir filtreleme yap.
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

            // --- 2. ADIM: HAFIZADA FİLTRELEME ---
            // Gelen sonuçları, kod içinde kategoriye göre kendimiz filtreliyoruz.
            // Bu yöntem %100 güvenlidir ve SwiftData hatasına yol açmaz.
            let ilgiliIslemler = tumDonemGiderleri.filter { islem in
                guard let kategoriID = islem.kategori?.id else { return false }
                return kategoriIDSet.contains(kategoriID)
            }
            
            self.donemIslemleri = ilgiliIslemler
            
            // Harcanan tutarı ve gösterilecek bütçe nesnesini güncelle
            let harcananTutar = ilgiliIslemler.reduce(0) { $0 + $1.tutar }
            self.gosterilecekButce = GosterilecekButce(butce: self.butce, harcananTutar: harcananTutar)
            
        } catch {
            Logger.log("Bütçe detay verisi çekilirken hata oluştu: \(error.localizedDescription)", log: Logger.data, type: .error)
        }
    }
    
    func deleteSingleTransaction(_ islem: Islem, context: ModelContext) {
        TransactionService.shared.deleteTransaction(islem, in: context)
    }

    /// Tekrarlanan bir işlem serisini arka planda siler.
    func deleteTransactionSeries(_ islem: Islem) async {
        guard let container = modelContainer else { return }
        await TransactionService.shared.deleteSeriesInBackground(tekrarID: islem.tekrarID, from: container)
    }
    
    /// Taksitli bir işlemin tüm serisini siler.
    func deleteInstallmentTransaction(_ islem: Islem, context: ModelContext) {
        TransactionService.shared.deleteTaksitliIslem(islem, in: context)
    }
}
