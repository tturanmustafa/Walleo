import Foundation
import SwiftData

enum BildirimTuru: String, Codable {
    case butceLimitiYaklasti = "bütçe.limit.yaklaştı"
    case butceLimitiAsildi = "bütçe.limit.aşıldı"
    case taksitHatirlatici = "taksit.hatırlatıcı"
    case krediKartiOdemeGunu = "kart.ödeme.günü"
}

@Model
class Bildirim {
    @Attribute(.unique) var id: UUID
    var turRawValue: String
    var olusturmaTarihi: Date
    var okunduMu: Bool
    
    // YÖNLENDİRME İÇİN
    var hedefID: UUID?
    
    // --- DEĞİŞİKLİK: METİN YERİNE HAM VERİ SAKLAMA ---
    // Her bildirim türü, sadece ihtiyacı olan alanları dolduracak.
    var ilgiliIsim: String?      // Bütçe adı, Kredi kartı adı vb.
    var tutar1: Double?          // Limit tutarı, vb.
    var tutar2: Double?          // Aşan tutar, vb.
    var tarih1: Date?            // Son ödeme tarihi, vb.
    
    var tur: BildirimTuru {
        get { BildirimTuru(rawValue: turRawValue) ?? .butceLimitiAsildi }
        set { turRawValue = newValue.rawValue }
    }
    
    init(tur: BildirimTuru, olusturmaTarihi: Date = Date(), okunduMu: Bool = false, hedefID: UUID? = nil, ilgiliIsim: String? = nil, tutar1: Double? = nil, tutar2: Double? = nil, tarih1: Date? = nil) {
        self.id = UUID()
        self.turRawValue = tur.rawValue
        self.olusturmaTarihi = olusturmaTarihi
        self.okunduMu = okunduMu
        self.hedefID = hedefID
        self.ilgiliIsim = ilgiliIsim
        self.tutar1 = tutar1
        self.tutar2 = tutar2
        self.tarih1 = tarih1
    }
}
