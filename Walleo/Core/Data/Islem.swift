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
    
    // YENİ: Tekrarlanan işlemler için opsiyonel bitiş tarihi alanı
    var tekrarBitisTarihi: Date?
    
    // YENİ: Taksitli işlem alanları
    var taksitliMi: Bool = false
    var toplamTaksitSayisi: Int = 0
    var mevcutTaksitNo: Int = 0
    var anaTaksitliIslemID: UUID?
    var anaIslemTutari: Double = 0.0 // Toplam tutar bilgisi için
    
    @Relationship(deleteRule: .nullify)
    var kategori: Kategori?
    
    @Relationship(deleteRule: .nullify)
    var hesap: Hesap?

    var tur: IslemTuru {
        get { IslemTuru(rawValue: turRawValue) ?? .gider }
        set { turRawValue = newValue.rawValue }
    }
    
    // GÜNCELLEME: init metodu yeni alanları içerecek şekilde güncellendi
    init(
        id: UUID = UUID(),
        isim: String,
        tutar: Double,
        tarih: Date,
        tur: IslemTuru,
        tekrar: TekrarTuru = .tekSeferlik,
        tekrarID: UUID = UUID(),
        kategori: Kategori?,
        hesap: Hesap? = nil,
        tekrarBitisTarihi: Date? = nil,
        taksitliMi: Bool = false,
        toplamTaksitSayisi: Int = 0,
        mevcutTaksitNo: Int = 0,
        anaTaksitliIslemID: UUID? = nil,
        anaIslemTutari: Double = 0.0
    ) {
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
        self.taksitliMi = taksitliMi
        self.toplamTaksitSayisi = toplamTaksitSayisi
        self.mevcutTaksitNo = mevcutTaksitNo
        self.anaTaksitliIslemID = anaTaksitliIslemID
        self.anaIslemTutari = anaIslemTutari
    }
}
