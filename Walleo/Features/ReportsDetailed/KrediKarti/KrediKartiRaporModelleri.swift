// >> GÜNCELLENECEK DOSYA: Features/ReportsDetailed/KrediKartiRaporModelleri.swift

import Foundation
import SwiftUI

// MARK: - Temel Modeller

struct KrediKartiGenelOzet {
    var toplamHarcama: Double = 0.0
    var islemSayisi: Int = 0
    var enCokKullanilanKart: Hesap?
    var enYuksekHarcama: Islem?
    var toplamLimit: Double = 0.0
    var toplamKullanilabilir: Double = 0.0
}

struct KartDetayRaporu: Identifiable {
    let id: UUID
    let hesap: Hesap
    var toplamHarcama: Double = 0.0
    var guncelBorc: Double = 0.0
    var limit: Double = 0.0
    var kullanilabilir: Double = 0.0
    var kategoriDagilimi: [KategoriHarcamasi] = []
    var gunlukHarcamaTrendi: [GunlukHarcama] = []
    var haftalikIsiHaritasi: [HaftalikHarcama] = []
    var tahmin: LimitTahmini?
    var kategoriTrendleri: [KategoriTrend] = []
}

// MARK: - Yeni Analiz Modelleri

struct HarcamaAnalizi {
    let gunlukOrtalamaHarcama: Double
    let enSikHarcamaGunu: GunAnalizi?
    let kategoriTrendleri: [KategoriTrend]
    let tahminiBorcKapama: Date?
}

struct GunAnalizi {
    let gun: String
    let yuzde: Double
    let ortalamaTutar: Double
}

struct KategoriTrend: Identifiable {
    let id = UUID()
    let kategori: Kategori
    let oncekiAy: Double
    let buAy: Double
    let degisimYuzdesi: Double
    let trend: TrendYonu
}

enum TrendYonu {
    case yukselis, dusus, sabit
    
    var ikon: String {
        switch self {
        case .yukselis: return "arrow.up.right"
        case .dusus: return "arrow.down.right"
        case .sabit: return "minus"
        }
    }
    
    var renk: Color {
        switch self {
        case .yukselis: return .red
        case .dusus: return .green
        case .sabit: return .gray
        }
    }
}

struct LimitTahmini {
    let mevcutKullanimOrani: Double
    let tahminEdileAysonuKullanim: Double
    let riskSeviyesi: RiskSeviyesi
    let onerilenGunlukLimit: Double
    let tahminiBorcKapamaTarihi: Date?
}

enum RiskSeviyesi: Int {
    case dusuk = 1
    case orta = 2
    case yuksek = 3
    
    var renk: Color {
        switch self {
        case .dusuk: return .green
        case .orta: return .orange
        case .yuksek: return .red
        }
    }
    
    var mesajKey: String {
        switch self {
        case .dusuk: return "risk.level.low"
        case .orta: return "risk.level.medium"
        case .yuksek: return "risk.level.high"
        }
    }
}

struct GunlukHarcama: Identifiable {
    let id = UUID()
    let gun: Date
    let tutar: Double
    let islemSayisi: Int
}

struct HaftalikHarcama: Identifiable {
    let id = UUID()
    let haftaBaslangici: Date
    let gunler: [GunlukVeri]
}

struct GunlukVeri: Identifiable {
    let id = UUID()
    let gun: Date
    let harcama: Double
    let yogunluk: Double // 0.0 - 1.0 arası normalize edilmiş
}

// MARK: - İçgörü Modeli

struct KrediKartiIcgorusu: Identifiable {
    let id = UUID()
    let ikon: String
    let mesajKey: String
    let parametreler: [String: Any]
    let oncelik: Int
    let actionKey: String? // Opsiyonel aksiyon
}
