//
//  KrediKartiGenelOzet.swift
//  Walleo
//
//  Created by Mustafa Turan on 14.07.2025.
//


// >> YENİ DOSYA: Features/Reports/Models/KrediKartiRaporModelleri.swift

import Foundation
import SwiftUI

// Kredi kartı raporunun genel özetini tutan model.
struct KrediKartiGenelOzet {
    var toplamHarcama: Double = 0.0
    var islemSayisi: Int = 0
    var enCokKullanilanKart: Hesap?
    var enYuksekHarcama: Islem?
}

// Her bir kartın kendi özel rapor verilerini tutan model.
struct KartDetayRaporu: Identifiable {
    let id: UUID
    let hesap: Hesap
    var toplamHarcama: Double = 0.0
    var kategoriDagilimi: [KategoriHarcamasi] = [] // Pasta grafiği için
    var gunlukHarcamaTrendi: [GunlukHarcama] = [] // Çizgi grafiği için
}

// Çizgi grafiğindeki her bir noktayı temsil eden model.
struct GunlukHarcama: Identifiable {
    let id = UUID()
    let gun: Date
    let tutar: Double
}