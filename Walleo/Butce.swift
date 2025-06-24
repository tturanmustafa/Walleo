import Foundation
import SwiftData

@Model
class Butce {
    // @Attribute(.unique) kaldırıldı ve özelliklere varsayılan değerler atandı.
    var id: UUID = UUID()
    var isim: String = ""
    var limitTutar: Double = 0.0
    var olusturmaTarihi: Date = Date()
    var tekrarAraligi: ButceTekrarAraligi = ButceTekrarAraligi.aylik

    @Relationship(deleteRule: .nullify)
    var kategoriler: [Kategori]?

    init(isim: String, limitTutar: Double, tekrarAraligi: ButceTekrarAraligi = .aylik, kategoriler: [Kategori] = []) {
        self.id = UUID()
        self.isim = isim
        self.limitTutar = limitTutar
        self.olusturmaTarihi = Date()
        self.tekrarAraligi = tekrarAraligi
        self.kategoriler = kategoriler
    }
}
