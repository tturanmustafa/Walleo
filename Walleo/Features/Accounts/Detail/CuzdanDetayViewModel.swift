// Dosya: CuzdanDetayViewModel.swift

import SwiftUI
import SwiftData

@MainActor
@Observable
class CuzdanDetayViewModel {
    // DÜZELTME: modelContext artık opsiyonel.
    var modelContext: ModelContext?
    var hesap: Hesap
    
    var currentDate = Date() {
        didSet { islemleriGetir() }
    }
    
    var donemIslemleri: [Islem] = []
    var toplamGelir: Double = 0.0
    var toplamGider: Double = 0.0
    
    // DÜZELTME: init artık context almıyor.
    init(hesap: Hesap) {
        self.hesap = hesap
    }
    
    // YENİ FONKSİYON: View göründüğünde çağrılarak doğru context ile başlatılır.
    func initialize(modelContext: ModelContext) {
        guard self.modelContext == nil else { return } // Sadece bir kere başlatılmasını garantiler.
        
        self.modelContext = modelContext
        islemleriGetir() // İlk veriyi çek
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(islemleriGetir),
            name: .transactionsDidChange,
            object: nil
        )
    }
    
    @objc func islemleriGetir() {
        // DÜZELTME: Artık opsiyonel olan context güvenli bir şekilde kullanılır.
        guard let modelContext = self.modelContext else { return }
        
        let calendar = Calendar.current
        guard let monthInterval = calendar.dateInterval(of: .month, for: currentDate) else { return }
        
        let hesapID = hesap.id
        
        let predicate = #Predicate<Islem> { islem in
            islem.hesap?.id == hesapID &&
            islem.tarih >= monthInterval.start &&
            islem.tarih < monthInterval.end
        }
        
        let descriptor = FetchDescriptor<Islem>(predicate: predicate, sortBy: [SortDescriptor(\.tarih, order: .reverse)])
        
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
