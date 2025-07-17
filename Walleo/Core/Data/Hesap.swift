import Foundation
import SwiftData
import SwiftUI

// +++ YENİ EKLENDİ +++
// Hesap türünü veritabanında sorgulanabilir hale getirmek için.
enum HesapTuru: String, Codable {
    case cuzdan, krediKarti, kredi
}

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
    var id: UUID = UUID()
    var isim: String = ""
    var ikonAdi: String = ""
    var renkHex: String = ""
    var olusturmaTarihi: Date = Date()
    var baslangicBakiyesi: Double = 0.0
    
    var hesapTuruRawValue: String = HesapTuru.cuzdan.rawValue
    
    // ÖNEMLİ: Varsayılan değeri kaldırıyoruz
    private var detayData: Data?
    
    @Relationship(deleteRule: .nullify, inverse: \Islem.hesap)
    var islemler: [Islem]? = []
    
    @Relationship(deleteRule: .nullify, inverse: \Transfer.kaynakHesap)
    var gidenTransferler: [Transfer]? = []

    @Relationship(deleteRule: .nullify, inverse: \Transfer.hedefHesap)
    var gelenTransferler: [Transfer]? = []
    
    var detay: HesapDetayi {
        get {
            guard let data = detayData else { return .cuzdan }
            do {
                return try JSONDecoder().decode(HesapDetayi.self, from: data)
            } catch {
                Logger.log("HesapDetayi çözümlenemedi: \(error)", log: Logger.data, type: .error)
                return .cuzdan
            }
        }
        set {
            do {
                detayData = try JSONEncoder().encode(newValue)
                
                // hesapTuruRawValue'yi güncelle
                switch newValue {
                case .cuzdan:
                    self.hesapTuruRawValue = HesapTuru.cuzdan.rawValue
                case .krediKarti:
                    self.hesapTuruRawValue = HesapTuru.krediKarti.rawValue
                case .kredi:
                    self.hesapTuruRawValue = HesapTuru.kredi.rawValue
                }
                
                Logger.log("Hesap detayı güncellendi: \(String(describing: newValue))", log: Logger.data)
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
        
        // Detayı encode etmeden önce logla
        Logger.log("Init'e gelen detay: \(String(describing: detay))", log: Logger.data)
        
        do {
            self.detayData = try JSONEncoder().encode(detay)
            
            switch detay {
            case .cuzdan:
                self.hesapTuruRawValue = HesapTuru.cuzdan.rawValue
            case .krediKarti(let limit, _, _):
                self.hesapTuruRawValue = HesapTuru.krediKarti.rawValue
                Logger.log("Kredi kartı init - Limit: \(limit)", log: Logger.data)
            case .kredi(let tutar, _, _, let taksitSayisi, _, _):
                self.hesapTuruRawValue = HesapTuru.kredi.rawValue
                Logger.log("Kredi init - Tutar: \(tutar), Taksit: \(taksitSayisi)", log: Logger.data)
            }
            
            // Kayıttan sonra kontrol
            Logger.log("Kaydedilen hesap türü: \(self.hesapTuruRawValue)", log: Logger.data)
            
        } catch {
            Logger.log("Init sırasında HesapDetayi encode edilemedi: \(error)", log: Logger.data, type: .error)
            self.detayData = try? JSONEncoder().encode(HesapDetayi.cuzdan)
            self.hesapTuruRawValue = HesapTuru.cuzdan.rawValue
        }
    }
}
