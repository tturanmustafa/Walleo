//
//  RaporTuru.swift
//  Walleo
//
//  Created by Mustafa Turan on 14.07.2025.
//


import Foundation
import SwiftUI

enum RaporTuru: String, CaseIterable, Identifiable {
    case nakitAkisi
    case kategoriRadari
    case harcamaAliskanliklari
    case gelirVeHesaplar
    case borcYonetimi
    case butcePerformansi
    case abonelikler
    case donemselKarsilastirma
    case finansalAnlik
    
    var id: String { rawValue }
    
    var baslik: LocalizedStringKey {
        switch self {
        case .nakitAkisi: return "detailed_reports.cash_flow.title"
        case .kategoriRadari: return "detailed_reports.category_radar.title"
        case .harcamaAliskanliklari: return "detailed_reports.spending_habits.title"
        case .gelirVeHesaplar: return "detailed_reports.income_accounts.title"
        case .borcYonetimi: return "detailed_reports.debt_management.title"
        case .butcePerformansi: return "detailed_reports.budget_performance.title"
        case .abonelikler: return "detailed_reports.subscriptions.title"
        case .donemselKarsilastirma: return "detailed_reports.period_comparison.title"
        case .finansalAnlik: return "detailed_reports.financial_snapshot.title"
        }
    }
    
    var kısaBaslik: LocalizedStringKey {
        switch self {
        case .nakitAkisi: return "detailed_reports.cash_flow.short"
        case .kategoriRadari: return "detailed_reports.category_radar.short"
        case .harcamaAliskanliklari: return "detailed_reports.spending_habits.short"
        case .gelirVeHesaplar: return "detailed_reports.income_accounts.short"
        case .borcYonetimi: return "detailed_reports.debt_management.short"
        case .butcePerformansi: return "detailed_reports.budget_performance.short"
        case .abonelikler: return "detailed_reports.subscriptions.short"
        case .donemselKarsilastirma: return "detailed_reports.period_comparison.short"
        case .finansalAnlik: return "detailed_reports.financial_snapshot.short"
        }
    }
    
    var ikon: String {
        switch self {
        case .nakitAkisi: return "chart.line.uptrend.xyaxis"
        case .kategoriRadari: return "chart.pie"
        case .harcamaAliskanliklari: return "clock.arrow.circlepath"
        case .gelirVeHesaplar: return "banknote"
        case .borcYonetimi: return "creditcard"
        case .butcePerformansi: return "target"
        case .abonelikler: return "arrow.triangle.2.circlepath"
        case .donemselKarsilastirma: return "chart.bar.xaxis"
        case .finansalAnlik: return "camera.viewfinder"
        }
    }
}

enum YuklemeDurumu: Equatable {
    case bekliyor
    case yukleniyor
    case basarili
    case hata(String)
}

// MARK: - Nakit Akışı Modelleri
struct NakitAkisVerisi: Identifiable {
    let id = UUID()
    let tarih: Date
    let gelir: Double
    let gider: Double
    let netAkis: Double
    let kumulatifBakiye: Double
}

// MARK: - Kategori Analiz Modelleri
struct KategoriAnalizVerisi: Identifiable {
    let id = UUID()
    let kategori: Kategori
    let toplamTutar: Double
    let islemSayisi: Int
    let ortalamaIslem: Double
    let yuzde: Double
}

// MARK: - Harcama Alışkanlığı Modelleri
struct HarcamaAliskanligiVerisi {
    let saatlikDagilim: [Int: Double]
    let gunlukDagilim: [Int: Double] // 1-7 (Pzt-Paz)
    let odemeYontemiDagilimi: [String: Double]
    let ortalamaHarcama: Double
    let enYogunSaat: Int
    let enYogunGun: Int
}

// MARK: - Hesap Hareket Modelleri
struct HesapHareketVerisi: Identifiable {
    let id = UUID()
    let hesap: Hesap
    let donemBasiBakiye: Double
    let donemSonuBakiye: Double
    let toplamGelir: Double
    let toplamGider: Double
    let islemSayisi: Int
    let netDegisim: Double
}

// MARK: - Abonelik Modelleri
struct AbonelikVerisi: Identifiable {
    let id = UUID()
    let isim: String
    let kategori: Kategori
    let tutar: Double
    let tekrarTuru: TekrarTuru
    let sonrakiOdemeTarihi: Date
    let yillikMaliyet: Double
}

// MARK: - Dönemsel Karşılaştırma Modelleri
struct DonemselKarsilastirmaVerisi {
    let mevcutDonem: DonemVerisi
    let oncekiDonem: DonemVerisi
    let degisimler: [KategoriDegisim]
}

struct DonemVerisi {
    let baslangic: Date
    let bitis: Date
    let toplamGelir: Double
    let toplamGider: Double
    let netAkis: Double
}

struct KategoriDegisim: Identifiable {
    let id = UUID()
    let kategori: Kategori
    let eskiTutar: Double
    let yeniTutar: Double
    let degisimYuzdesi: Double
}

// MARK: - Finansal Anlık Modelleri
struct FinansalAnlikVerisi {
    let toplamVarlik: Double
    let toplamBorc: Double
    let netDeger: Double
    let varliklar: [VarlikDetay]
    let borclar: [BorcDetay]
    let gunlukDegisimler: [NetDegerDegisim]
}

struct VarlikDetay: Identifiable {
    let id = UUID()
    let hesap: Hesap
    let bakiye: Double
}

struct BorcDetay: Identifiable {
    let id = UUID()
    let hesap: Hesap
    let borc: Double
}

struct NetDegerDegisim: Identifiable {
    let id = UUID()
    let tarih: Date
    let netDeger: Double
}