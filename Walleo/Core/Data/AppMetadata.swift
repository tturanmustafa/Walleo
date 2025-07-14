import Foundation
import SwiftData

@Model
class AppMetadata {
    // ÇÖZÜM: Özelliğe tanımlandığı yerde varsayılan bir değer atıyoruz.
    var defaultCategoriesAdded: Bool = false

    // init fonksiyonu aynı kalabilir, bir zararı yok.
    init(defaultCategoriesAdded: Bool = false) {
        self.defaultCategoriesAdded = defaultCategoriesAdded
    }
}
