import Foundation
import SwiftData

@Model
class Islem {
    // Tüm özelliklere varsayılan değerler atandı.
    var id: UUID = UUID()
    var isim: String = ""
    var tutar: Double = 0.0
    var tarih: Date = Date()
    var turRawValue: String = IslemTuru.gider.rawValue
    var tekrar: TekrarTuru = TekrarTuru.tekSeferlik
    var tekrarID: UUID = UUID()
    
    @Relationship(deleteRule: .nullify)
    var kategori: Kategori?
    
    @Relationship(deleteRule: .nullify)
    var hesap: Hesap?

    var tur: IslemTuru {
        get { IslemTuru(rawValue: turRawValue) ?? .gider }
        set { turRawValue = newValue.rawValue }
    }
    
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
