import Foundation
import SwiftData
import SwiftUI

@Model
class Kategori {
    // ... diğer özellikler aynı kalıyor ...
    var id: UUID = UUID()
    var isim: String = ""
    var ikonAdi: String = ""
    var renkHex: String = ""
    var localizationKey: String?
    var turRawValue: String = IslemTuru.gider.rawValue

    @Relationship(deleteRule: .nullify, inverse: \Islem.kategori)
    var islemler: [Islem]?
    
    @Relationship(inverse: \Butce.kategoriler)
    var butceler: [Butce]?
    
    var tur: IslemTuru {
        get { IslemTuru(rawValue: turRawValue) ?? .gider }
        set { turRawValue = newValue.rawValue }
    }
    
    var renk: Color { Color(hex: renkHex) }
    
    // Dolu olan init fonksiyonu kalacak
    init(id: UUID = UUID(), isim: String, ikonAdi: String, tur: IslemTuru, renkHex: String, localizationKey: String? = nil) {
        self.id = id
        self.isim = isim
        self.ikonAdi = ikonAdi
        self.renkHex = renkHex
        self.localizationKey = localizationKey
        self.turRawValue = tur.rawValue
    }
}
