// Dosya: ButceDetayViewModel.swift

import SwiftUI
import SwiftData

@MainActor
@Observable
class ButceDetayViewModel {
    var modelContext: ModelContext?
    var butce: Butce
    
    var gosterilecekButce: GosterilecekButce?
    var donemIslemleri: [Islem] = []
    
    init(butce: Butce) {
        self.butce = butce
    }
    
    func initialize(modelContext: ModelContext) {
        guard self.modelContext == nil else { return }
        
        self.modelContext = modelContext
        
        Task {
            await fetchData()
        }
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(fetchDataWrapper),
            name: .transactionsDidChange,
            object: nil
        )
    }
    
    @objc private func fetchDataWrapper() {
        Task { await fetchData() }
    }
    
    func deleteButce() {
        guard let modelContext = self.modelContext else { return }
        modelContext.delete(butce)
        NotificationCenter.default.post(name: .transactionsDidChange, object: nil)
    }

    func fetchData() async {
        guard let modelContext = self.modelContext else {
            Logger.log("ButceDetayViewModel henüz başlatılmamış.", log: Logger.service, type: .error)
            return
        }
        
        let calendar = Calendar.current
        guard let monthInterval = calendar.dateInterval(of: .month, for: Date()) else { return }

        do {
            guard let kategoriIDleri = butce.kategoriler?.map({ $0.id }), !kategoriIDleri.isEmpty else {
                self.donemIslemleri = []
                self.gosterilecekButce = GosterilecekButce(butce: self.butce, harcananTutar: 0)
                return
            }
            let kategoriIDSet = Set(kategoriIDleri)
            
            let giderTuruRawValue = IslemTuru.gider.rawValue
            let descriptor = FetchDescriptor<Islem>(
                predicate: #Predicate { islem in
                    islem.tarih >= monthInterval.start &&
                    islem.tarih < monthInterval.end &&
                    islem.turRawValue == giderTuruRawValue
                },
                sortBy: [SortDescriptor(\.tarih, order: .reverse)]
            )
            let tumAylikGiderler = try modelContext.fetch(descriptor)
            
            let ilgiliIslemler = tumAylikGiderler.filter { islem in
                guard let islemKategoriID = islem.kategori?.id else { return false }
                return kategoriIDSet.contains(islemKategoriID)
            }
            
            self.donemIslemleri = ilgiliIslemler
            let harcananTutar = ilgiliIslemler.reduce(0) { $0 + $1.tutar }
            self.gosterilecekButce = GosterilecekButce(butce: self.butce, harcananTutar: harcananTutar)
            
        } catch {
            Logger.log("Bütçe detay verisi çekilirken hata oluştu: \(error.localizedDescription)", log: Logger.data, type: .error)
        }
    }
}
