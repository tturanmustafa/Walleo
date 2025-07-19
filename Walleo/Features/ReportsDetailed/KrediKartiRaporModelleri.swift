// Walleo/Features/ReportsDetailed/Models/KrediKartiRaporModelleri.swift

import Foundation
import SwiftUI

// MARK: - Genel Özet Modeli
struct KrediKartiGenelOzet {
    var toplamHarcama: Double = 0.0
    var islemSayisi: Int = 0
    var enCokKullanilanKart: Hesap?
    var enYuksekHarcama: Islem?
    var aktifKartSayisi: Int = 0
    var gunlukOrtalama: Double = 0.0
    var oncekiDonemeDegisimYuzdesi: Double?
    var enCokKullanilanKartKullanimOrani: Double?
}

// MARK: - Kart Detay Raporu
struct KartDetayRaporu: Identifiable {
    let id: UUID
    let hesap: Hesap
    var toplamHarcama: Double = 0.0
    var kategoriDagilimi: [KategoriHarcamasi] = []
    var gunlukHarcamaTrendi: [GunlukHarcama] = []
    
    // Ek özellikler
    var islemSayisi: Int?
    var ortalamaIslemTutari: Double?
    var enYuksekGunlukHarcama: Double?
    var kartLimiti: Double?
    var guncelBorc: Double?
    var kullanilabilirLimit: Double?
    var kartDolulukOrani: Double?
    var taksitliIslemler: [TaksitliIslemOzeti] = []
    var kategoriZamanliDagilim: [KategoriZamanliDagilim]?
}

// MARK: - Günlük Harcama
struct GunlukHarcama: Identifiable {
    let id = UUID()
    let gun: Date
    let tutar: Double
    var islemSayisi: Int?
}

// MARK: - Kategori Harcaması

// MARK: - Taksitli İşlem Özeti
struct TaksitliIslemOzeti: Identifiable {
    let id: UUID
    let isim: String
    let toplamTutar: Double
    let aylikTaksitTutari: Double
    let odenenTaksitSayisi: Int
    let toplamTaksitSayisi: Int
    let kalanTutar: Double
}

// MARK: - Kategori Zamanlı Dağılım
struct KategoriZamanliDagilim: Identifiable {
    let id = UUID()
    let tarih: Date
    let kategoriAdi: String
    let tutar: Double
}

// LocalizedStringKey extension for getting string value
extension LocalizedStringKey {
    var stringKey: String? {
        let mirror = Mirror(reflecting: self)
        if let displayStyle = mirror.displayStyle, displayStyle == .struct {
            for case let (label?, value) in mirror.children {
                if label == "key" {
                    return value as? String
                }
            }
        }
        return nil
    }
}
