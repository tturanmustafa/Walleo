import Foundation
import SwiftData

enum BildirimTuru: String, Codable {
    case butceLimitiYaklasti = "bütçe.limit.yaklaştı"
    case butceLimitiAsildi = "bütçe.limit.aşıldı"
    case taksitHatirlatici = "taksit.hatırlatıcı"
    case krediKartiOdemeGunu = "kart.ödeme.günü"
    case butceYenilemeOncesi = "bütçe.yenileme.öncesi"
    case butceYenilemeSonrasi = "bütçe.yenileme.sonrası"
}

@Model
class Bildirim {
    // @Attribute(.unique) kaldırıldı ve özelliklere varsayılan değerler atandı.
    var id: UUID = UUID()
    var turRawValue: String = ""
    var olusturmaTarihi: Date = Date()
    var okunduMu: Bool = false
    
    // Opsiyonel alanların varsayılan değeri zaten nil'dir.
    var hedefID: UUID?
    var ilgiliIsim: String?
    var tutar1: Double?
    var tutar2: Double?
    var tarih1: Date?
    
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
