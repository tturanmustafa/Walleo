import SwiftUI
import SwiftData

@MainActor
@Observable
class KrediKartiDetayViewModel {
    var modelContext: ModelContext
    var kartHesabi: Hesap
    
    var donemIslemleri: [Islem] = []
    
    init(modelContext: ModelContext, kartHesabi: Hesap) {
        self.modelContext = modelContext
        self.kartHesabi = kartHesabi
    }
    
    func islemleriGetir() {
        // --- DÜZELTME BURADA ---
        // Artık 3 parametreli (limit, kesimTarihi, ofset) case'i doğru şekilde karşılıyoruz.
        // Limit ve ofset'i kullanmadığımız için _ ile atlıyoruz.
        guard case .krediKarti(_, let kesimTarihi, _) = kartHesabi.detay else { return }
        
        // Bu dönemin başlangıç ve bitiş tarihlerini hesapla
        let takvim = Calendar.current
        let bugun = takvim.startOfDay(for: Date())
        var bilesenler = takvim.dateComponents([.year, .month], from: bugun)
        bilesenler.day = takvim.component(.day, from: kesimTarihi)

        guard let buAykiKesimGunu = takvim.date(from: bilesenler) else { return }
        let donemBitisTarihi = buAykiKesimGunu > bugun ? takvim.date(byAdding: .month, value: -1, to: buAykiKesimGunu)! : buAykiKesimGunu
        
        // donemBitisTarihi'nden bir ay geriye giderek başlangıç tarihini bulma (daha güvenli yol)
        guard let donemBaslangicTarihi = takvim.date(byAdding: .month, value: -1, to: donemBitisTarihi) else { return }
        
        let kartID = kartHesabi.id
        let predicate = #Predicate<Islem> { islem in
            islem.hesap?.id == kartID &&
            islem.tarih > donemBaslangicTarihi &&
            islem.tarih <= donemBitisTarihi
        }
        
        let descriptor = FetchDescriptor<Islem>(predicate: predicate, sortBy: [SortDescriptor(\.tarih, order: .reverse)])
        
        do {
            donemIslemleri = try modelContext.fetch(descriptor)
        } catch {
            print("Kredi kartı işlemleri çekilirken hata: \(error)")
        }
    }
}
