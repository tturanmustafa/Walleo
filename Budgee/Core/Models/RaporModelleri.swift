import Foundation
import SwiftUI

// MARK: - Rapor Veri Modelleri

// Ana Metrikler ve İstatistikler kartları için veri modeli
struct OzetVerisi {
    var toplamGelir: Double = 0.0
    var toplamGider: Double = 0.0
    var netAkis: Double { toplamGelir - toplamGider }
    
    var gunlukOrtalamaHarcama: Double = 0.0
    var gunlukOrtalamaGelir: Double = 0.0 // YENİ EKLENDİ
    var toplamIslemSayisi: Int = 0
    var enYuksekHarcama: Islem?
    var enYuksekGelir: Islem?
}

// Karşılaştırma Analizi kartı için veri modeli
struct KarsilastirmaVerisi {
    var giderDegisimYuzdesi: Double?
    var netAkisFarki: Double?
    var anaKategoriHarcamaFarki: (kategoriAdi: String, fark: Double)?
}

// En Çok Harcanan/Kazanılan kategoriler listesi için tek bir satırın modeli
struct KategoriOzetSatiri: Identifiable, Hashable {
    let id: UUID
    let ikonAdi: String
    let renk: Color
    let kategoriAdi: String
    let tutar: Double
    let yuzde: Double // Toplam gidere/gelire oranı
}
// RaporModelleri.swift dosyasının en altına ekleyin


