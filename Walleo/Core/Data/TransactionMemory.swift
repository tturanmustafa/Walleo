// Dosya: TransactionMemory.swift

import Foundation
import SwiftData

@Model
class TransactionMemory {
    // 1. DÜZELTME: @Attribute(.unique) kaldırıldı çünkü CloudKit bunu desteklemiyor.
    // Benzersizliği kodumuzun içinde kendimiz yöneteceğiz (mevcut mantığımız zaten bunu yapıyor).
    var transactionNameKey: String = ""
    
    // 2. DÜZELTME: CloudKit senkronizasyonu için varsayılan bir başlangıç değeri atandı.
    var lastCategoryID: UUID = UUID()
    
    // init fonksiyonumuz aynı kalabilir.
    init(transactionNameKey: String, lastCategoryID: UUID) {
        self.transactionNameKey = transactionNameKey
        self.lastCategoryID = lastCategoryID
    }
}
