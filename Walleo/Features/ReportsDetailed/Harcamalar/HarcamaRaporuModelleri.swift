// Features/ReportsDetailed/Harcamalar/HarcamaRaporuModelleri.swift

import Foundation
import SwiftUI

// MARK: - Genel Özet
struct HarcamaGenelOzet {
    var toplamHarcama: Double = 0.0
    var islemSayisi: Int = 0
    var gunlukOrtalama: Double = 0.0
    var ortalamaIslemTutari: Double = 0.0
    var enYuksekHarcama: Islem?
    var oncekiDonemeGoreDegisim: (tutar: Double, yuzde: Double, aciklama: String)?
}

// MARK: - Kategori Modelleri
struct HarcamaKategoriOzet: Identifiable {
    let id: UUID
    let isim: String
    let localizationKey: String?
    let ikonAdi: String
    let renk: Color
    let tutar: Double
    let yuzde: Double
    let islemSayisi: Int
}

struct HarcamaKategoriDetay: Identifiable {
    let id: UUID
    let isim: String
    let localizationKey: String?
    let ikonAdi: String
    let renk: Color
    let toplamTutar: Double
    let yuzde: Double
    let islemSayisi: Int
    let gunlukDagilim: [HarcamaGunlukVeri]
    let enBuyukIslem: Islem?
    let ortalamaIslemTutari: Double
}

// MARK: - Zaman Modelleri
struct HarcamaGunlukVeri: Identifiable {
    let id = UUID()
    let gun: Date
    let tutar: Double
    let islemSayisi: Int?
}

struct HarcamaHaftalikVeri: Identifiable {
    let id = UUID()
    let haftaBasi: Date
    let toplamTutar: Double
    let gunSayisi: Int
    let islemSayisi: Int
    
    var gunlukOrtalama: Double {
        gunSayisi > 0 ? toplamTutar / Double(gunSayisi) : 0
    }
}

struct HarcamaSaatlikVeri: Identifiable {
    let id = UUID()
    let saat: Int
    let toplamTutar: Double
    let islemSayisi: Int
    let yuzde: Double
}

struct HarcamaHaftaKarsilastirma {
    var haftaIciToplam: Double = 0
    var haftaSonuToplam: Double = 0
    var haftaIciIslemSayisi: Int = 0
    var haftaSonuIslemSayisi: Int = 0
    
    var haftaIciOrtalama: Double {
        haftaIciIslemSayisi > 0 ? haftaIciToplam / Double(haftaIciIslemSayisi) : 0
    }
    
    var haftaSonuOrtalama: Double {
        haftaSonuIslemSayisi > 0 ? haftaSonuToplam / Double(haftaSonuIslemSayisi) : 0
    }
}

// MARK: - Karşılaştırma Modelleri
struct HarcamaDonemKarsilastirma {
    var oncekiDonemToplam: Double = 0
    var buDonemToplam: Double = 0
    var degisimTutari: Double = 0
    var degisimYuzdesi: Double = 0
}

struct HarcamaKategoriDegisim: Identifiable {
    let id = UUID()
    let kategori: HarcamaKategoriDetay
    let oncekiTutar: Double
    let mevcutTutar: Double
    let degisimTutari: Double
    let degisimYuzdesi: Double
}

// MARK: - Bütçe Performans
struct HarcamaButcePerformans: Identifiable {
    let id = UUID()
    let butce: Butce
    let harcananTutar: Double
    let kalanTutar: Double
    let kullanimOrani: Double
    let durum: ButceDurum
    
    enum ButceDurum {
        case normal, kritik, asildi
        
        var renk: Color {
            switch self {
            case .normal: return .green
            case .kritik: return .orange
            case .asildi: return .red
            }
        }
    }
}

// MARK: - İçgörü
struct HarcamaIcgoru: Identifiable {
    let id: UUID
    let tip: IcgoruTipi
    let mesaj: String
    let oncelik: Int
    
    enum IcgoruTipi {
        case bilgi, uyari, oneri
        
        var ikon: String {
            switch self {
            case .bilgi: return "info.circle.fill"
            case .uyari: return "exclamationmark.triangle.fill"
            case .oneri: return "lightbulb.fill"
            }
        }
        
        var renk: Color {
            switch self {
            case .bilgi: return .blue
            case .uyari: return .orange
            case .oneri: return .green
            }
        }
    }
}
