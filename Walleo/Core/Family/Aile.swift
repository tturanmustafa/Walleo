// Walleo/Core/Data/Aile.swift

import Foundation
import SwiftData
import CloudKit

@Model
class Aile {
    var id: UUID = UUID()
    var isim: String = ""
    var olusturmaTarihi: Date = Date()
    var sahipID: String = "" // CloudKit kullanıcı ID'si
    var sahipAdi: String = ""
    
    // CloudKit Share referansı için
    var shareRecordID: String?
    
    @Relationship(deleteRule: .cascade, inverse: \AileUyesi.aile)
    var uyeler: [AileUyesi]? = []
    
    init(isim: String, sahipID: String, sahipAdi: String) {
        self.id = UUID()
        self.isim = isim
        self.olusturmaTarihi = Date()
        self.sahipID = sahipID
        self.sahipAdi = sahipAdi
    }
}

@Model
class AileUyesi {
    var id: UUID = UUID()
    var userID: String = "" // CloudKit kullanıcı ID'si
    var adi: String = ""
    var email: String?
    var katilimTarihi: Date = Date()
    var davetDurumu: DavetDurumu = DavetDurumu.beklemede
    
    @Relationship(deleteRule: .nullify)
    var aile: Aile?
    
    init(userID: String, adi: String, email: String? = nil, davetDurumu: DavetDurumu = DavetDurumu.beklemede) {
        self.id = UUID()
        self.userID = userID
        self.adi = adi
        self.email = email
        self.katilimTarihi = Date()
        self.davetDurumu = davetDurumu
    }
}

enum DavetDurumu: String, Codable {
    case beklemede = "pending"
    case kabul = "accepted"
    case red = "rejected"
}

@Model
class AileDavet {
    var id: UUID = UUID()
    var aileID: UUID = UUID()
    var davetEdenID: String = ""
    var davetEdenAdi: String = ""
    var davetTarihi: Date = Date()
    var sonGecerlilikTarihi: Date = Date()
    var durum: DavetDurumu = DavetDurumu.beklemede
    var shareURL: String?
    
    init(aileID: UUID, davetEdenID: String, davetEdenAdi: String) {
        self.id = UUID()
        self.aileID = aileID
        self.davetEdenID = davetEdenID
        self.davetEdenAdi = davetEdenAdi
        self.davetTarihi = Date()
        self.sonGecerlilikTarihi = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        self.durum = DavetDurumu.beklemede
    }
}
