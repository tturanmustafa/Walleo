//
//  KrediKartiDetayViewModel.swift
//  Budgee
//
//  Created by Mustafa Turan on 19.06.2025.
//


// Dosya Adı: KrediKartiDetayViewModel.swift

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
        guard case .krediKarti(_, let kesimTarihi) = kartHesabi.detay else { return }
        
        // Bu dönemin başlangıç ve bitiş tarihlerini hesapla
        // Örnek: Kesim tarihi ayın 20'si ise, bir önceki ayın 21'inden bu ayın 20'sine kadar olan işlemleri alırız.
        let takvim = Calendar.current
        let bugun = takvim.startOfDay(for: Date())
        var bilesenler = takvim.dateComponents([.year, .month], from: bugun)
        bilesenler.day = takvim.component(.day, from: kesimTarihi)

        let buAykiKesimGunu = takvim.date(from: bilesenler)!
        let donemBitisTarihi = buAykiKesimGunu > bugun ? takvim.date(byAdding: .month, value: -1, to: buAykiKesimGunu)! : buAykiKesimGunu
        let donemBaslangicTarihi = takvim.date(byAdding: .month, value: -1, to: donemBitisTarihi)!
        
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