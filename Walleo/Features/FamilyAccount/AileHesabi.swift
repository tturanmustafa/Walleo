import Foundation
import SwiftData

@Model
class AileHesabi {
    var id: UUID = UUID()
    var isim: String = ""
    var adminID: String = ""
    var olusturmaTarihi: Date = Date()
    var guncellemeTarihi: Date = Date()
    
    @Relationship(deleteRule: .cascade)
    var uyeler: [AileUyesi]?
    
    init(isim: String, adminID: String) {
        self.id = UUID()
        self.isim = isim
        self.adminID = adminID
        self.olusturmaTarihi = Date()
        self.guncellemeTarihi = Date()
    }
}

@Model
class AileUyesi {
    var id: UUID = UUID()
    var appleID: String = ""
    var gorunumIsmi: String = ""
    var katilimTarihi: Date = Date()
    @Transient var durum: UyeDurum {
        get { UyeDurum(rawValue: durumRawValue) ?? .beklemede }
        set { durumRawValue = newValue.rawValue }
    }
    
    var durumRawValue: String = "beklemede"
    
    @Relationship(inverse: \AileHesabi.uyeler)
    var aileHesabi: AileHesabi?
    
    init(appleID: String, gorunumIsmi: String, durum: UyeDurum = .beklemede) {
        self.id = UUID()
        self.appleID = appleID
        self.gorunumIsmi = gorunumIsmi
        self.katilimTarihi = Date()
        self.durumRawValue = durum.rawValue
    }
}

enum UyeDurum: String, Codable {
    case beklemede = "beklemede"
    case aktif = "aktif"
    case reddedildi = "reddedildi"
}

