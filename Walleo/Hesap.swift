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
    // --- GÜNCELLEME BURADA ---
    // sonOdemeGunuOfseti: Hesap kesim tarihinden kaç gün sonra son ödeme günü olduğunu tutar.
    case krediKarti(limit: Double, kesimTarihi: Date, sonOdemeGunuOfseti: Int)
    // --- GÜNCELLEME SONU ---
    case kredi(
        cekilenTutar: Double,
        faizTipi: FaizTipi,
        faizOrani: Double,
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
    
    @Relationship(deleteRule: .nullify, inverse: \Islem.hesap)
    var islemler: [Islem]? = []
    
    var detay: HesapDetayi {
        get {
            do {
                return try JSONDecoder().decode(HesapDetayi.self, from: detayData)
            } catch {
                print("KRİTİK HATA: HesapDetayi deşifre edilemedi. Hesap ID: \(id). Hata: \(error)")
                return .cuzdan
            }
        }
        set {
            do {
                detayData = try JSONEncoder().encode(newValue)
            } catch {
                print("KRİTİK HATA: HesapDetayi şifrelenemedi. Hesap ID: \(id). Hata: \(error)")
            }
        }
    }
    
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
