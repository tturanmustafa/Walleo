// GÜNCELLEME: Islem.swift

import Foundation
import SwiftData

@Model
class Islem {
    var id: UUID = UUID()
    var isim: String = ""
    var tutar: Double = 0.0
    var tarih: Date = Date()
    var turRawValue: String = IslemTuru.gider.rawValue
    var tekrar: TekrarTuru = TekrarTuru.tekSeferlik
    var tekrarID: UUID = UUID()
    
    // YENİ: Tekrarlanan işlemler için opsiyonel bitiş tarihi alanı eklendi.
    var tekrarBitisTarihi: Date?
    
    @Relationship(deleteRule: .nullify)
    var kategori: Kategori?
    
    @Relationship(deleteRule: .nullify)
    var hesap: Hesap?

    var tur: IslemTuru {
        get { IslemTuru(rawValue: turRawValue) ?? .gider }
        set { turRawValue = newValue.rawValue }
    }
    
    // GÜNCELLEME: init metodu yeni alanı içerecek şekilde güncellendi.
    init(id: UUID = UUID(), isim: String, tutar: Double, tarih: Date, tur: IslemTuru, tekrar: TekrarTuru = .tekSeferlik, tekrarID: UUID = UUID(), kategori: Kategori?, hesap: Hesap? = nil, tekrarBitisTarihi: Date? = nil) {
        self.id = id
        self.isim = isim
        self.tutar = tutar
        self.tarih = tarih
        self.turRawValue = tur.rawValue
        self.tekrar = tekrar
        self.tekrarID = tekrarID
        self.kategori = kategori
        self.hesap = hesap
        self.tekrarBitisTarihi = tekrarBitisTarihi
    }
}
