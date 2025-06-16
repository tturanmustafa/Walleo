import Foundation
import SwiftData
import SwiftUI

@Model
class Kategori {
    @Attribute(.unique) var id: UUID
    var isim: String
    var ikonAdi: String
    var tur: IslemTuru
    var renkHex: String
    var localizationKey: String?

    @Relationship(deleteRule: .cascade, inverse: \Islem.kategori)
    var islemler: [Islem]?
    
    var renk: Color { Color(hex: renkHex) }
    
    // .displayName özelliği kaldırıldı.

    init(id: UUID = UUID(), isim: String, ikonAdi: String, tur: IslemTuru, renkHex: String, localizationKey: String? = nil) {
        self.id = id
        self.isim = isim
        self.ikonAdi = ikonAdi
        self.tur = tur
        self.renkHex = renkHex
        self.localizationKey = localizationKey
    }
}
