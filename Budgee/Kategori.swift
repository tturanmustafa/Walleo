// Kategori.swift

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

    // DEĞİŞİKLİK BURADA: .cascade yerine .nullify kullanıldı.
    @Relationship(deleteRule: .nullify, inverse: \Islem.kategori)
    var islemler: [Islem]?
    
    var renk: Color { Color(hex: renkHex) }
    
    init(id: UUID = UUID(), isim: String, ikonAdi: String, tur: IslemTuru, renkHex: String, localizationKey: String? = nil) {
        self.id = id
        self.isim = isim
        self.ikonAdi = ikonAdi
        self.tur = tur
        self.renkHex = renkHex
        self.localizationKey = localizationKey
    }
}
