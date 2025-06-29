import SwiftUI
import SwiftData

@MainActor
@Observable
class ButceDetayViewModel {
    var modelContext: ModelContext
    var butce: Butce
    
    var gosterilecekButce: GosterilecekButce?
    var donemIslemleri: [Islem] = []
    
    init(modelContext: ModelContext, butce: Butce) {
        self.modelContext = modelContext
        self.butce = butce
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(fetchDataWrapper),
            name: .transactionsDidChange,
            object: nil
        )
    }
    
    // @objc selector'ler asenkron fonksiyonları doğrudan çağıramaz, bu yüzden bir sarmalayıcı kullanıyoruz.
    @objc private func fetchDataWrapper() {
        Task { await fetchData() }
    }
    
    func fetchData() async {
        let calendar = Calendar.current
        guard let monthInterval = calendar.dateInterval(of: .month, for: Date()) else { return }

        do {
            let kategoriIDleri = Set(butce.kategoriler?.map { $0.id } ?? [])
            var harcananTutar: Double = 0
            
            if !kategoriIDleri.isEmpty {
                // --- OPTİMİZASYON BURADA ---
                // Önceki gibi tüm giderleri çekmek yerine,
                // Sadece bu bütçenin kategorilerine ait işlemleri çeken bir predicate oluşturuyoruz.
                let giderTuruRawValue = IslemTuru.gider.rawValue
                
                let predicate = #Predicate<Islem> { islem in
                    islem.tarih >= monthInterval.start &&
                    islem.tarih < monthInterval.end &&
                    islem.turRawValue == giderTuruRawValue &&
                    // Bu satır, filtrelemeyi doğrudan veritabanında yapar.
                    islem.kategori != nil && kategoriIDleri.contains(islem.kategori!.id)
                }
                
                let descriptor = FetchDescriptor<Islem>(predicate: predicate, sortBy: [SortDescriptor(\.tarih, order: .reverse)])
                let ilgiliIslemler = try modelContext.fetch(descriptor)
                // --- OPTİMİZASYON SONU ---
                
                self.donemIslemleri = ilgiliIslemler
                harcananTutar = self.donemIslemleri.reduce(0) { $0 + $1.tutar }
            }
            
            self.gosterilecekButce = GosterilecekButce(butce: self.butce, harcananTutar: harcananTutar)
            
        } catch {
            Logger.log("Bütçe detay verisi çekilirken hata oluştu: \(error.localizedDescription)", log: Logger.data, type: .error)
        }
    }
}
