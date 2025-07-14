//
//  RaporSonucu.swift
//  Walleo
//
//  Created by Mustafa Turan on 1.07.2025.
//


// Yeni Dosya: RaporSonucu.swift

import Foundation

/// RaporHesaplamaServisi tarafından yapılan hesaplamaların tüm sonuçlarını bir arada tutan veri yapısı.
struct RaporSonucu {
    let ozetVerisi: OzetVerisi
    let karsilastirmaVerisi: KarsilastirmaVerisi
    let topGiderKategorileri: [KategoriOzetSatiri]
    let topGelirKategorileri: [KategoriOzetSatiri]
    let giderDagilimVerisi: [KategoriOzetSatiri]
    let gelirDagilimVerisi: [KategoriOzetSatiri]
    
    // Boş bir başlangıç durumu için yardımcı.
    static func bos() -> RaporSonucu {
        return RaporSonucu(
            ozetVerisi: OzetVerisi(),
            karsilastirmaVerisi: KarsilastirmaVerisi(),
            topGiderKategorileri: [],
            topGelirKategorileri: [],
            giderDagilimVerisi: [],
            gelirDagilimVerisi: []
        )
    }
}