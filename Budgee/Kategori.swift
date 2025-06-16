import Foundation
import SwiftData
import SwiftUI // SwiftUI'ı ekliyoruz

@Model
class Kategori {
    @Attribute(.unique) var id: UUID
    var isim: String
    var ikonAdi: String
    var tur: IslemTuru
    var renkHex: String // YENİ: Rengi hex kodu olarak saklamak için

    @Relationship(deleteRule: .cascade, inverse: \Islem.kategori)
    var islemler: [Islem]?
    
    // YENİ: Hex kodunu SwiftUI'ın anladığı Color tipine çevirir.
    var renk: Color {
        Color(hex: renkHex)
    }

    init(id: UUID = UUID(), isim: String, ikonAdi: String, tur: IslemTuru, renkHex: String) {
        self.id = id
        self.isim = isim
        self.ikonAdi = ikonAdi
        self.tur = tur
        self.renkHex = renkHex
    }
}
