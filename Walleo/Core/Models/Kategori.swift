import Foundation
import SwiftData
import SwiftUI

@Model
class Kategori {
    @Attribute(.unique) var id: UUID
    var isim: String
    var ikonAdi: String
    var renkHex: String
    var localizationKey: String?
    
    // DÜZELTME 1: 'tur' değişkenini 'turRawValue' olarak değiştiriyoruz.
    // Bu, SwiftData'nın enum'ı güvenli bir şekilde String olarak saklamasını sağlar.
    var turRawValue: String

    @Relationship(deleteRule: .nullify, inverse: \Islem.kategori)
    var islemler: [Islem]?
    
    @Relationship(inverse: \Butce.kategoriler)
    var butceler: [Butce]?
    
    // DÜZELTME 2: Kodun geri kalanında kolayca kullanabilmek için
    // 'tur' adında bir hesaplanmış değişken ekliyoruz.
    var tur: IslemTuru {
        get { IslemTuru(rawValue: turRawValue) ?? .gider }
        set { turRawValue = newValue.rawValue }
    }
    
    var renk: Color { Color(hex: renkHex) }
    
    // DÜZELTME 3: init metodu artık 'turRawValue' değil, 'tur' alacak
    // ve atamayı kendi içinde yapacak. Bu, kullanımı kolaylaştırır.
    init(id: UUID = UUID(), isim: String, ikonAdi: String, tur: IslemTuru, renkHex: String, localizationKey: String? = nil) {
        self.id = id
        self.isim = isim
        self.ikonAdi = ikonAdi
        self.renkHex = renkHex
        self.localizationKey = localizationKey
        self.turRawValue = tur.rawValue
    }
}
