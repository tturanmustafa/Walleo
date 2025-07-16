import Foundation
import SwiftUI

// MARK: - Kategori Rapor Modelleri

struct KategoriRaporVerisi: Identifiable { // Identifiable eklendi
    let id = UUID() // id property eklendi
    let kategori: Kategori
    let toplamTutar: Double
    let islemSayisi: Int
    let ortalamaTutar: Double
    let gunlukOrtalama: Double
    let aylikTrend: [AylikTrendNokta]
    let enSikKullanilanIsimler: [IsimFrekansi]
    let gunlereGoreDagilim: [GunlukDagilim]
    let saatlereGoreDagilim: [SaatlikDagilim]
}

// Diğer struct'lar aynı kalacak...
struct AylikTrendNokta: Identifiable {
    let id = UUID()
    let ay: Date
    let tutar: Double
    let islemSayisi: Int
}

struct IsimFrekansi: Identifiable {
    let id = UUID()
    let isim: String
    let frekans: Int
    let toplamTutar: Double
    let ortalamatutar: Double
}

struct GunlukDagilim: Identifiable {
    let id = UUID()
    let gunAdi: String
    let tutar: Double
    let islemSayisi: Int
}

struct SaatlikDagilim: Identifiable {
    let id = UUID()
    let saat: Int
    let tutar: Double
    let islemSayisi: Int
}

// Kategori karşılaştırma için
struct KategoriKarsilastirma: Identifiable {
    let id = UUID()
    let kategori: Kategori
    let mevcutDonemTutar: Double
    let oncekiDonemTutar: Double
    let degisimYuzdesi: Double
    let siralama: Int
    let oncekiSiralama: Int
}

// Genel özet
struct KategoriRaporOzet {
    let toplamKategoriSayisi: Int
    let aktifKategoriSayisi: Int // İşlem yapılmış kategoriler
    let toplamHarcama: Double
    let toplamGelir: Double
    let enCokHarcananKategori: Kategori?
    let enCokGelirGetiren: Kategori?
}
