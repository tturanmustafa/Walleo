//
//  CuzdanDetayViewModel.swift
//  Walleo
//
//  Created by Mustafa Turan on 28.06.2025.
//


// YENİ DOSYA: CuzdanDetayViewModel.swift

import SwiftUI
import SwiftData

@MainActor
@Observable
class CuzdanDetayViewModel {
    var modelContext: ModelContext
    var hesap: Hesap
    
    var currentDate = Date() {
        didSet { islemleriGetir() }
    }
    
    var donemIslemleri: [Islem] = []
    var toplamGelir: Double = 0.0
    var toplamGider: Double = 0.0
    
    init(modelContext: ModelContext, hesap: Hesap) {
        self.modelContext = modelContext
        self.hesap = hesap
        islemleriGetir() // İlk açılışta veriyi çek
        
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
        
        let hesapID = hesap.id
        
        // ÖNEMLİ: Bu sorgu, kredi kartından farklı olarak, hem gelir hem de giderleri çeker.
        let predicate = #Predicate<Islem> { islem in
            islem.hesap?.id == hesapID &&
            islem.tarih >= monthInterval.start &&
            islem.tarih < monthInterval.end
        }
        
        let descriptor = FetchDescriptor<Islem>(predicate: predicate, sortBy: [SortDescriptor(\.tarih, order: .reverse)])
        
        do {
            let islemler = try modelContext.fetch(descriptor)
            self.donemIslemleri = islemler
            
            // Toplamları hesapla
            self.toplamGelir = islemler.filter { $0.tur == .gelir }.reduce(0) { $0 + $1.tutar }
            self.toplamGider = islemler.filter { $0.tur == .gider }.reduce(0) { $0 + $1.tutar }
            
        } catch {
            Logger.log("Cüzdan detay işlemleri çekilirken hata: \(error.localizedDescription)", log: Logger.data, type: .error)
        }
    }
}