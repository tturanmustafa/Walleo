// Dosya: Islem.swift (GÜNCELLENMİŞ HALİ)

import Foundation
import SwiftData

@Model
class Islem {
    var id: UUID
    var isim: String
    var tutar: Double
    var tarih: Date
    var turRawValue: String
    var tekrar: TekrarTuru
    var tekrarID: UUID
    
    @Relationship(deleteRule: .nullify)
    var kategori: Kategori?
    
    // === YENİ SATIR ===
    // Her işlem artık bir 'Hesap' nesnesine bağlanabilir.
    @Relationship(deleteRule: .nullify)
    var hesap: Hesap?

    var tur: IslemTuru {
        get { IslemTuru(rawValue: turRawValue) ?? .gider }
        set { turRawValue = newValue.rawValue }
    }
    
    // === GÜNCELLENMİŞ INIT ===
    init(id: UUID = UUID(), isim: String, tutar: Double, tarih: Date, tur: IslemTuru, tekrar: TekrarTuru = .tekSeferlik, tekrarID: UUID = UUID(), kategori: Kategori?, hesap: Hesap? = nil) {
        self.id = id
        self.isim = isim
        self.tutar = tutar
        self.tarih = tarih
        self.turRawValue = tur.rawValue
        self.tekrar = tekrar
        self.tekrarID = tekrarID
        self.kategori = kategori
        self.hesap = hesap
    }
}
