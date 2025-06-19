import Foundation
import SwiftData

@Model
class Islem {
    var id: UUID
    var isim: String
    var tutar: Double
    var tarih: Date
    
    // DEĞİŞİKLİK 1: Veritabanında türü artık String olarak saklıyoruz.
    var turRawValue: String
    
    var tekrar: TekrarTuru
    var tekrarID: UUID
    
    @Relationship(deleteRule: .nullify)
    var kategori: Kategori?

    // DEĞİŞİKLİK 2: Kodun geri kalanında kolaylık olması için 'tur' adında bir hesaplanmış değişken ekliyoruz.
    // Bu değişken veritabanına kaydedilmez, sadece anlık olarak string'i enum'a çevirir.
    var tur: IslemTuru {
        get { IslemTuru(rawValue: turRawValue) ?? .gider }
        set { turRawValue = newValue.rawValue }
    }
    
    // DEĞİŞİKLİK 3: init metodunu yeni yapıya uygun güncelliyoruz.
    init(id: UUID = UUID(), isim: String, tutar: Double, tarih: Date, tur: IslemTuru, tekrar: TekrarTuru = .tekSeferlik, tekrarID: UUID = UUID(), kategori: Kategori?) {
        self.id = id
        self.isim = isim
        self.tutar = tutar
        self.tarih = tarih
        self.turRawValue = tur.rawValue // Gelen enum'ı string'e çevirip saklıyoruz.
        self.tekrar = tekrar
        self.tekrarID = tekrarID
        self.kategori = kategori
    }
}
