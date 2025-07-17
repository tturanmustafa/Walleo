import Foundation
import SwiftData

@Model
class Butce {
    // MARK: - Temel Bütçe Bilgileri
    
    var id: UUID = UUID()
    var isim: String = ""
    var limitTutar: Double = 0.0
    var olusturmaTarihi: Date = Date()
    
    // MARK: - Akıllı Bütçe Alanları (Kullanıcının Ayarladığı)

    /// Bu bütçenin hangi aya ve yıla ait olduğunu belirtir (Örn: 2025-07-01).
    /// Gruplama ve geçmiş takibi için kullanılır.
    var periyot: Date = Date()
    
    /// Bütçenin her ay otomatik olarak yenilenip yenilenmeyeceğini belirler.
    var otomatikYenile: Bool = true
    
    /// Önceki aydan artan pozitif bakiyenin yeni aya devredilip edilmeyeceğini belirler.
    var devredenBakiyeEtkin: Bool = false
    
    // MARK: - Otomasyon Alanları (Sistemin Doldurduğu)

    /// Bir önceki aydan bu bütçeye ne kadar tutarın devredildiğini gösterir.
    var devredenGelenTutar: Double = 0.0
    
    /// "Haziran'dan: 150 TL" gibi detaylı devir geçmişini JSON olarak saklar.
    var devredenGecmisiJSON: String?

    /// Bu bütçenin, hangi ana "şablon" bütçeden yenilenerek türediğini belirtir.
    var anaButceID: UUID?

    // MARK: - İlişkiler ve Eski Alanlar

    // Bu alan ileride haftalık/yıllık bütçeler için kullanılabilir.
    var tekrarAraligi: ButceTekrarAraligi = ButceTekrarAraligi.aylik

    @Relationship(deleteRule: .nullify)
    var kategoriler: [Kategori]?
    
    @Relationship(inverse: \Kategori.butceler)
    var kategoriIliskisi: [Kategori]?

    // MARK: - Yardımcı Kod (Computed Property)

    /// `devredenGecmisi` (Data) alanını, kullanılabilir bir Sözlük [String: Double] yapısına çevirir.
    /// Bu, kodun diğer yerlerinde bu veriyi kolayca okuyup yazmamızı sağlar.
    var devirGecmisiSozlugu: [String: Double] {
        get {
            guard let jsonString = devredenGecmisiJSON,
                  let data = jsonString.data(using: .utf8) else { return [:] }
            do {
                return try JSONDecoder().decode([String: Double].self, from: data)
            } catch {
                Logger.log("Devir geçmişi JSON'dan dönüştürülemedi: \(error)", log: Logger.data)
                return [:]
            }
        }
        set {
            do {
                let data = try JSONEncoder().encode(newValue)
                devredenGecmisiJSON = String(data: data, encoding: .utf8)
            } catch {
                Logger.log("Devir geçmişi JSON'a dönüştürülemedi: \(error)", log: Logger.data)
            }
        }
    }

    // MARK: - Init Fonksiyonu

    /// Yeni bir Bütçe nesnesi oluşturur.
    init(
        isim: String,
        limitTutar: Double,
        periyot: Date,
        otomatikYenile: Bool = true,
        devredenBakiyeEtkin: Bool = false,
        kategoriler: [Kategori] = [],
        anaButceID: UUID? = nil,
        devredenGelenTutar: Double = 0.0
    ) {
        self.id = UUID()
        self.isim = isim
        self.limitTutar = limitTutar
        self.olusturmaTarihi = Date()
        self.periyot = periyot
        self.otomatikYenile = otomatikYenile
        self.devredenBakiyeEtkin = devredenBakiyeEtkin
        self.kategoriler = kategoriler
        self.anaButceID = anaButceID
        self.devredenGelenTutar = devredenGelenTutar
    }
}
