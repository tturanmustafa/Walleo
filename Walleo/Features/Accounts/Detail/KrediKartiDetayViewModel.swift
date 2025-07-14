import SwiftUI
import SwiftData

@MainActor
@Observable
class KrediKartiDetayViewModel {
    var modelContext: ModelContext
    var kartHesabi: Hesap
    
    var donemIslemleri: [Islem] = []
    var currentDate = Date() {
        didSet {
            islemleriGetir()
        }
    }
    
    // YENİ EKLENEN HESAPLANMIŞ DEĞİŞKEN
    var toplamHarcama: Double {
        donemIslemleri.reduce(0) { $0 + $1.tutar }
    }
    
    init(modelContext: ModelContext, kartHesabi: Hesap) {
        self.modelContext = modelContext
        self.kartHesabi = kartHesabi
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(islemleriGetir),
            name: .transactionsDidChange,
            object: nil
        )
    }
    
    @objc func islemleriGetir() {
        let calendar = Calendar.current
        guard let monthInterval = calendar.dateInterval(of: .month, for: currentDate) else { return }
        
        let kartID = kartHesabi.id
        let giderTuruRawValue = IslemTuru.gider.rawValue
        
        let predicate = #Predicate<Islem> { islem in
            islem.hesap?.id == kartID &&
            islem.tarih >= monthInterval.start &&
            islem.tarih < monthInterval.end &&
            islem.turRawValue == giderTuruRawValue
        }
        
        let descriptor = FetchDescriptor<Islem>(predicate: predicate, sortBy: [SortDescriptor(\.tarih, order: .reverse)])
        
        do {
            donemIslemleri = try modelContext.fetch(descriptor)
        } catch {
            Logger.log("Kredi kartı detay işlemleri çekilirken hata: \(error.localizedDescription)", log: Logger.data, type: .error)
        }
    }
}
