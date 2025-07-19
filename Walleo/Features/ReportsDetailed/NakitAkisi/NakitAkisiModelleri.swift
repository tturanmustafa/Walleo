//
//  NakitAkisiRaporu.swift
//  Walleo
//
//  Created by Mustafa Turan on 18.07.2025.
//


// Walleo/Features/ReportsDetailed/NakitAkisi/NakitAkisiModelleri.swift

import Foundation
import SwiftUI

// MARK: - Ana Nakit Akışı Modeli
struct NakitAkisiRaporu {
    let baslangicTarihi: Date
    let bitisTarihi: Date
    let toplamGelir: Double
    let toplamGider: Double
    let netAkis: Double
    let gunlukAkisVerisi: [GunlukNakitAkisi]
    let islemTipiDagilimi: IslemTipiDagilimi
    let kategoriAkislari: [KategoriNakitAkisi]
    let hesapAkislari: [HesapNakitAkisi]
    let gelecekProjeksiyonu: GelecekProjeksiyonu
    let transferOzeti: TransferOzeti
}

// MARK: - Günlük Nakit Akışı
struct GunlukNakitAkisi: Identifiable {
    let id = UUID()
    let tarih: Date
    let gelir: Double
    let gider: Double
    let netAkis: Double
    let kumulatifBakiye: Double
    
    // İşlem detayları
    let normalGelir: Double
    let normalGider: Double
    let taksitliGelir: Double
    let taksitliGider: Double
    let tekrarliGelir: Double
    let tekrarliGider: Double
}

// MARK: - İşlem Tipi Dağılımı
struct IslemTipiDagilimi {
    let normalIslemler: IslemTipiOzet
    let taksitliIslemler: IslemTipiOzet
    let tekrarliIslemler: IslemTipiOzet
    
    struct IslemTipiOzet {
        let gelirSayisi: Int
        let giderSayisi: Int
        let toplamGelir: Double
        let toplamGider: Double
        let netEtki: Double
        let yuzdePayi: Double // Toplam işlem içindeki payı
    }
}

// MARK: - Kategori Bazlı Nakit Akışı
struct KategoriNakitAkisi: Identifiable {
    let id: UUID
    let kategori: Kategori
    let toplamTutar: Double
    let islemSayisi: Int
    let ortalamaIslemTutari: Double
    let akisTrendi: [TrendNokta] // Mini trend grafiği için
    let enBuyukIslem: Islem?
    
    struct TrendNokta: Identifiable {
        let id = UUID()
        let tarih: Date
        let tutar: Double
    }
}

// MARK: - Hesap Bazlı Nakit Akışı
struct HesapNakitAkisi: Identifiable {
    let id: UUID
    let hesap: Hesap
    let baslangicBakiyesi: Double
    let donemSonuBakiyesi: Double
    let toplamGiris: Double // Gelirler + Gelen transferler
    let toplamCikis: Double // Giderler + Giden transferler
    let netDegisim: Double
    let islemSayisi: Int
    let gunlukOrtalama: Double
}

// MARK: - Gelecek Projeksiyonu
struct GelecekProjeksiyonu {
    let projeksiyonSuresi: Int // Gün sayısı
    let tahminiGelir: Double
    let tahminiGider: Double
    let tahminiNetAkis: Double
    let gunlukProjeksiyon: [GunlukProjeksiyon]
    let riskSeviyesi: RiskSeviyesi
    
    struct GunlukProjeksiyon: Identifiable {
        let id = UUID()
        let tarih: Date
        let tahminiGelir: Double
        let tahminiGider: Double
        let tahminiKumulatifBakiye: Double
    }
    
    enum RiskSeviyesi {
        case dusuk, orta, yuksek
        
        var renk: Color {
            switch self {
            case .dusuk: return .green
            case .orta: return .orange
            case .yuksek: return .red
            }
        }
        
        var mesaj: String {
            switch self {
            case .dusuk: return "cashflow.risk.low"
            case .orta: return "cashflow.risk.medium"
            case .yuksek: return "cashflow.risk.high"
            }
        }
    }
}

// MARK: - Transfer Özeti
struct TransferOzeti {
    let toplamTransferSayisi: Int
    let toplamTransferTutari: Double
    let enSikTransferYapilan: (kaynak: Hesap?, hedef: Hesap?)?
    let transferDetaylari: [TransferDetay]
    
    struct TransferDetay: Identifiable {
        let id = UUID()
        let kaynakHesap: Hesap
        let hedefHesap: Hesap
        let toplamTutar: Double
        let islemSayisi: Int
    }
}

// MARK: - Akış İçgörüleri
struct NakitAkisiIcgoru: Identifiable {
    let id = UUID()
    let tip: IcgoruTipi
    let baslik: String
    let mesajKey: String
    let parametreler: [CVarArg]
    let oncelik: Int
    let ikon: String
    let renk: Color
    
    enum IcgoruTipi {
        case pozitifAkis
        case negatifAkis
        case yuksekTaksit
        case tekrarliGelir
        case kategoriUyari
        case hesapUyari
        case projeksiyonUyari
    }
}
