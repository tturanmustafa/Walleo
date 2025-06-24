import Foundation
import SwiftData
import SwiftUI

// Enum tanımlamaları aynı kalıyor...
enum FaizTipi: String, Codable, CaseIterable {
    case yillik = "Yıllık"
    case aylik = "Aylık"
    var localizedKey: String {
        switch self {
        case .yillik: return "enum.interest_type.yearly"
        case .aylik: return "enum.interest_type.monthly"
        }
    }
}
struct KrediTaksitDetayi: Codable, Identifiable {
    var id = UUID()
    var taksitTutari: Double
    var odemeTarihi: Date
    var odendiMi: Bool = false
}
enum HesapDetayi: Codable {
    case cuzdan
    case krediKarti(limit: Double, kesimTarihi: Date, sonOdemeGunuOfseti: Int)
    case kredi(cekilenTutar: Double, faizTipi: FaizTipi, faizOrani: Double, taksitSayisi: Int, ilkTaksitTarihi: Date, taksitler: [KrediTaksitDetayi])
}


@Model
class Hesap {
    // @Attribute(.unique) kaldırıldı ve özelliklere varsayılan değerler atandı.
    var id: UUID = UUID()
    var isim: String = ""
    var ikonAdi: String = ""
    var renkHex: String = ""
    var olusturmaTarihi: Date = Date()
    var baslangicBakiyesi: Double = 0.0
    
    // Güvenli bir varsayılan değer atıyoruz.
    private var detayData: Data = try! JSONEncoder().encode(HesapDetayi.cuzdan)
    
    @Relationship(deleteRule: .nullify, inverse: \Islem.hesap)
    var islemler: [Islem]? = []
    
    var detay: HesapDetayi {
        get {
            do {
                return try JSONDecoder().decode(HesapDetayi.self, from: detayData)
            } catch {
                // Varsayılan değere dönemediğinde kritik bir sorun var demektir.
                return .cuzdan
            }
        }
        set {
            do {
                detayData = try JSONEncoder().encode(newValue)
            } catch {
                Logger.log("HesapDetayi şifrelenemedi: \(error.localizedDescription)", log: Logger.data, type: .error)
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
        self.detay = detay
    }
}
