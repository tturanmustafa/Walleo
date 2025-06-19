// Dosya Adı: Hesap.swift (NİHAİ ÇÖZÜM)

import Foundation
import SwiftData
import SwiftUI

enum FaizTipi: String, Codable, CaseIterable {
    case yillik = "Yıllık"
    case aylik = "Aylık"
}

struct KrediTaksitDetayi: Codable, Identifiable {
    var id = UUID()
    var taksitTutari: Double
    var odemeTarihi: Date
    var odendiMi: Bool = false
}

enum HesapDetayi: Codable {
    case cuzdan
    case krediKarti(limit: Double, kesimTarihi: Date)
    case kredi(
        cekilenTutar: Double,
        faizTipi: FaizTipi,
        faizOrani: Double,
        // --- 1. TEMEL KURAL: Taksit sayısı burada 'Int' olarak tanımlanmalıdır. ---
        taksitSayisi: Int,
        ilkTaksitTarihi: Date,
        taksitler: [KrediTaksitDetayi]
    )
}

@Model
class Hesap {
    @Attribute(.unique) var id: UUID
    var isim: String
    var ikonAdi: String
    var renkHex: String
    var olusturmaTarihi: Date
    var baslangicBakiyesi: Double
    private var detayData: Data
    
    var detay: HesapDetayi {
        get { try! JSONDecoder().decode(HesapDetayi.self, from: detayData) }
        set { detayData = try! JSONEncoder().encode(newValue) }
    }
    
    @Relationship(deleteRule: .nullify, inverse: \Islem.hesap)
    var islemler: [Islem]? = []
    
    var renk: Color { Color(hex: renkHex) }
    
    init(isim: String, ikonAdi: String, renkHex: String, baslangicBakiyesi: Double, detay: HesapDetayi) {
        self.id = UUID()
        self.isim = isim
        self.ikonAdi = ikonAdi
        self.renkHex = renkHex
        self.olusturmaTarihi = Date()
        self.baslangicBakiyesi = baslangicBakiyesi
        self.detayData = try! JSONEncoder().encode(detay)
    }
}
