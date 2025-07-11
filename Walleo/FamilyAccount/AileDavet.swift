import Foundation
import SwiftData

@Model
class AileDavet {
    var id: UUID = UUID()
    var aileHesabiID: UUID = UUID()
    var aileHesabiIsmi: String = ""
    var davetEdenID: String = ""
    var davetEdenIsim: String = ""
    var davetEdilenID: String = ""
    var olusturmaTarihi: Date = Date()
    var gecerlilikTarihi: Date = Date()
    @Transient var durum: DavetDurum {
        get { DavetDurum(rawValue: durumRawValue) ?? .beklemede }
        set { durumRawValue = newValue.rawValue }
    }
    
    var durumRawValue: String = "beklemede"
    
    init(aileHesabiID: UUID, aileHesabiIsmi: String, davetEdenID: String,
         davetEdenIsim: String, davetEdilenID: String) {
        self.id = UUID()
        self.aileHesabiID = aileHesabiID
        self.aileHesabiIsmi = aileHesabiIsmi
        self.davetEdenID = davetEdenID
        self.davetEdenIsim = davetEdenIsim
        self.davetEdilenID = davetEdilenID
        self.olusturmaTarihi = Date()
        self.gecerlilikTarihi = Calendar.current.date(byAdding: .day, value: 7, to: Date())!
        self.durumRawValue = DavetDurum.beklemede.rawValue
    }
}

enum DavetDurum: String, Codable {
    case beklemede = "beklemede"
    case kabul = "kabul"
    case red = "red"
    case suresiDoldu = "suresiDoldu"
}

