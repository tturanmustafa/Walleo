//
//  KrediGenelOzet.swift
//  Walleo
//
//  Created by Mustafa Turan on 14.07.2025.
//


// >> YENİ DOSYA: Features/Reports/Models/KrediRaporModelleri.swift

import Foundation

// Kredi raporunun en üstteki genel özetini tutan model.
struct KrediGenelOzet {
    var aktifKrediSayisi: Int = 0
    var donemdekiToplamTaksitTutari: Double = 0.0
    var odenenToplamTaksitTutari: Double = 0.0
    var odenenTaksitSayisi: Int = 0
    var odenmeyenTaksitSayisi: Int = 0
}

// Her bir kredinin kendi özel rapor verilerini tutan model.
struct KrediDetayRaporu: Identifiable {
    let id: UUID
    let hesap: Hesap
    var donemdekiTaksitler: [KrediTaksitDetayi] = []

    // Hesaplanan Özellikler
    var donemdekiTaksitTutari: Double {
        donemdekiTaksitler.reduce(0) { $0 + $1.taksitTutari }
    }
    var odenenTaksitler: [KrediTaksitDetayi] {
        donemdekiTaksitler.filter { $0.odendiMi }
    }
    var odenmeyenTaksitler: [KrediTaksitDetayi] {
        donemdekiTaksitler.filter { !$0.odendiMi && $0.odemeTarihi < Date() } // Vadesi geçmiş olanlar
    }
    var gelecekTaksitler: [KrediTaksitDetayi] {
        donemdekiTaksitler.filter { !$0.odendiMi && $0.odemeTarihi >= Date() } // Vadesi gelmemiş olanlar
    }
}