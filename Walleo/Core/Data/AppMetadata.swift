import Foundation
import SwiftData

@Model
class AppMetadata {
    // ÇÖZÜM: Özelliğe tanımlandığı yerde varsayılan bir değer atıyoruz.
    var defaultCategoriesAdded: Bool = false
    
    // YENİ: Kullanıcının başlangıçtaki kategori sayısını tut (geriye uyumluluk için)
    var initialUserCategoryCount: Int = -1 // -1: henüz hesaplanmadı

    // init fonksiyonu güncellendi
    init(defaultCategoriesAdded: Bool = false, initialUserCategoryCount: Int = -1) {
        self.defaultCategoriesAdded = defaultCategoriesAdded
        self.initialUserCategoryCount = initialUserCategoryCount
    }
}
