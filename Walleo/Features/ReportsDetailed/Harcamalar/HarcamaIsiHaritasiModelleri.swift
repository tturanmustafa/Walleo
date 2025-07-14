// >> GÜNCELLENECEK DOSYA: Features/ReportsDetailed/Models/HarcamaIsiHaritasiModelleri.swift

import Foundation
import SwiftUI

// MARK: - Isı Haritası Veri Modelleri

struct IsiHaritasiVerisi {
    let baslangicTarihi: Date
    let bitisTarihi: Date
    let gunSayisi: Int
    let toplamHarcama: Double
    let toplamIslemSayisi: Int
    let zamanDilimleri: [ZamanDilimiVerisi]
}

struct ZamanDilimiVerisi: Identifiable {
    let id = UUID()
    let tarih: Date
    let periyot: ZamanPeriyodu
    let toplamTutar: Double
    let islemSayisi: Int
    let kategoriBazliTutar: [UUID: Double] // Kategori ID -> Tutar
    
    var normalizeEdilmisYogunluk: Double = 0.0 // 0.0 - 1.0 arası
}

enum ZamanPeriyodu {
    case saat(Date) // Belirli bir saat
    case gun(Date) // Belirli bir gün
    case hafta(Date, Date) // Hafta başı ve sonu
    case ay(Int, Int) // Ay ve yıl
}

// MARK: - Radyal Grafik Modeli

struct SaatlikDagilimVerisi: Identifiable { // <--- Identifiable eklendi
    var id: Int { saat } // <--- Benzersiz ID olarak 'saat' kullanıldı
    let saat: Int // 0-23
    let toplamTutar: Double
    let islemSayisi: Int
    let yuzde: Double
}

// MARK: - Karşılaştırma Modelleri

enum KarsilastirmaTipi {
    case gunlukDilimler // Sabah/Öğle/Akşam/Gece
    case gunler // Pazartesi, Salı...
    case haftaIciSonu // Hafta içi vs Hafta sonu
    case haftalar // 1. hafta, 2. hafta...
    case aylar // Ocak, Şubat...
    case ceyrekler // Q1, Q2...
}

// Harcama Isı Haritası için özel karşılaştırma verisi
struct HarcamaKarsilastirmaVerisi: Identifiable {
    let id = UUID()
    let etiket: String
    let localizationKey: String?
    let deger: Double
    let yuzde: Double
    let renk: Color
}

// MARK: - İçgörü Modeli

struct HarcamaIcgorusu: Identifiable {
    let id = UUID()
    let ikon: String
    let mesajKey: String
    let parametreler: [String: Any]
    let oncelik: Int // Sıralama için
}
