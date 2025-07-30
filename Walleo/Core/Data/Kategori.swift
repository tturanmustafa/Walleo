// Walleo/Core/Data/Kategori.swift
import Foundation
import SwiftData
import SwiftUI

@Model
class Kategori {
    var id: UUID = UUID()
    var isim: String = ""
    var ikonAdi: String = ""
    var renkHex: String = ""
    var localizationKey: String?
    var turRawValue: String = IslemTuru.gider.rawValue
    var olusturmaTarihi: Date = Date()

    @Relationship(deleteRule: .nullify, inverse: \Islem.kategori)
    var islemler: [Islem]?
    
    @Relationship(inverse: \Butce.kategoriler)
    var butceler: [Butce]?
    
    var tur: IslemTuru {
        get { IslemTuru(rawValue: turRawValue) ?? .gider }
        set { turRawValue = newValue.rawValue }
    }
    
    var renk: Color { Color(hex: renkHex) }
    
    init(id: UUID = UUID(), isim: String, ikonAdi: String, tur: IslemTuru, renkHex: String, localizationKey: String? = nil) {
        self.id = id
        self.isim = isim
        self.ikonAdi = ikonAdi
        self.renkHex = renkHex
        self.localizationKey = localizationKey
        self.turRawValue = tur.rawValue
        self.olusturmaTarihi = Date()
        
        // DEBUG LOG
        if let locKey = localizationKey {
            Logger.log("Kategori oluşturuluyor - İsim: \(isim), LocalizationKey: \(locKey)", log: Logger.data)
        }
    }
}
