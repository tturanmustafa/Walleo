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
                // --- DÜZELTME BAŞLANGICI ---
                // 1. ADIM: Daha basit bir sorguyla ilgili aydaki tüm giderleri çek.
                let giderTuruRawValue = IslemTuru.gider.rawValue
                let genelIslemPredicate = #Predicate<Islem> { islem in
                    islem.tarih >= monthInterval.start &&
                    islem.tarih < monthInterval.end &&
                    islem.turRawValue == giderTuruRawValue
                }
                let tumAylikGiderler = try modelContext.fetch(FetchDescriptor<Islem>(predicate: genelIslemPredicate))
                
                // 2. ADIM: Hafızada, bu bütçenin kategorilerine göre filtrele.
                let ilgiliIslemler = tumAylikGiderler.filter { islem in
                    guard let kategoriID = islem.kategori?.id else { return false }
                    return kategoriIDleri.contains(kategoriID)
                }
                // --- DÜZELTME SONU ---
                
                // Sonuçları sırala ve ata.
                self.donemIslemleri = ilgiliIslemler.sorted(by: { $0.tarih > $1.tarih })
                harcananTutar = self.donemIslemleri.reduce(0) { $0 + $1.tutar }
            }
            
            self.gosterilecekButce = GosterilecekButce(butce: self.butce, harcananTutar: harcananTutar)
            
        } catch {
            Logger.log("Bütçe detay verisi çekilirken hata oluştu: \(error.localizedDescription)", log: Logger.data, type: .error)
        }
    }
}
