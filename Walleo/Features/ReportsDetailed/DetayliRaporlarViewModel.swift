//
//  DetayliRaporlarViewModel.swift
//  Walleo
//
//  Created by Mustafa Turan on 14.07.2025.
//


// >> YENİ DOSYA: Features/Reports/DetayliRaporlarViewModel.swift

import SwiftUI

@MainActor
@Observable
class DetayliRaporlarViewModel {
    // 1. Başlangıç ve bitiş tarihleri için State değişkenleri.
    // Varsayılan olarak içinde bulunulan ayın ilk ve son gününü atayacağız.
    var baslangicTarihi: Date
    var bitisTarihi: Date

    init() {
        let takvim = Calendar.current
        let bugun = Date()
        
        // 2. Ayın başlangıcını ve sonunu güvenli bir şekilde hesapla.
        if let ayAraligi = takvim.dateInterval(of: .month, for: bugun) {
            self.baslangicTarihi = ayAraligi.start
            // Bitiş tarihi, bir sonraki ayın başlangıcından bir gün öncedir.
            self.bitisTarihi = takvim.date(byAdding: .day, value: -1, to: ayAraligi.end) ?? ayAraligi.end
        } else {
            // Hata durumunda varsayılan olarak bugünü ata.
            self.baslangicTarihi = bugun
            self.bitisTarihi = bugun
        }
        
        // Veri çekme fonksiyonu gelecekte buraya eklenecek.
        // fetchData()
    }

    // Gelecekteki fazlarda bu fonksiyonu dolduracağız.
    func fetchData() {
        // Kredi kartı ve kredi raporu verileri burada çekilecek.
        print("Seçili Tarih Aralığı: \(baslangicTarihi) - \(bitisTarihi)")
    }
}