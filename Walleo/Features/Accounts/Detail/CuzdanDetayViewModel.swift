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
            islemleriGetir()
            transferleriGetir()
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
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(verilerDegisti),
            name: .transactionsDidChange,
            object: nil
        )
    }
    
    @objc private func verilerDegisti() {
        islemleriGetir()
        transferleriGetir()
    }
    
    func transferleriGetir() {
        guard let modelContext = self.modelContext else { return }
        
        let hesapID = hesap.id
        let predicate = #Predicate<Transfer> { transfer in
            transfer.kaynakHesap?.id == hesapID || transfer.hedefHesap?.id == hesapID
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
    
    private func islemleriGetir() {
        guard let modelContext = self.modelContext else { return }
        
        let calendar = Calendar.current
        guard let monthInterval = calendar.dateInterval(of: .month, for: currentDate) else { return }
        
        let hesapID = hesap.id
        
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
