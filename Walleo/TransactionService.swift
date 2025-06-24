//
//  DeletionScope.swift
//  Walleo
//
//  Created by Mustafa Turan on 24.06.2025.
//


import Foundation
import SwiftData

/// İşlem silme operasyonunun kapsamını belirler.
enum DeletionScope {
    /// Sadece tek bir işlem silinir.
    case single
    /// İşlemin ait olduğu tüm tekrarlanan seri silinir.
    case series
}

/// Uygulama genelindeki işlem (Transaction) ile ilgili iş mantıklarını yöneten merkezi servis.
class TransactionService {
    
    /// Servisin tekil örneği (Singleton).
    static let shared = TransactionService()
    
    /// Dışarıdan yeni bir örnek oluşturulmasını engeller.
    private init() {}
    
    /// Bir işlemi veya ait olduğu seriyi veritabanından siler ve ilgili ekranların güncellenmesi için bildirim yayınlar.
    ///
    /// - Parameters:
    ///   - islem: Silinecek olan `Islem` nesnesi.
    ///   - context: İşlemin yapılacağı `ModelContext`.
    ///   - scope: Silme işleminin kapsamı (`.single` veya `.series`).
    func deleteTransaction(_ islem: Islem, in context: ModelContext, scope: DeletionScope) {
        // Hangi hesabın etkilendiğini takip etmek için bir set oluşturuyoruz.
        // Bu, sadece ilgili hesap kartının güncellenmesini sağlar.
        var affectedAccountIDs: Set<UUID> = []
        if let hesapID = islem.hesap?.id {
            affectedAccountIDs.insert(hesapID)
        }
        
        // Eğer işlem tek seferlikse veya sadece tek bir tanesi silinmek isteniyorsa
        if scope == .single || islem.tekrar == .tekSeferlik {
            context.delete(islem)
            print("TransactionService: Tek bir işlem silindi. ID: \(islem.id)")
        } else { // scope == .series ise tüm seriyi sil
            let tekrarID = islem.tekrarID
            // tekrarID'si boş veya varsayılan UUID ise bir hata olmaması için kontrol
            guard tekrarID != UUID() else {
                context.delete(islem)
                print("TransactionService: Seri silinmek istendi ancak tekrarID geçersizdi. Sadece tek işlem silindi. ID: \(islem.id)")
                return
            }
            
            try? context.delete(model: Islem.self, where: #Predicate { $0.tekrarID == tekrarID })
            print("TransactionService: Tüm seri silindi. TekrarID: \(tekrarID)")
        }
        
        // Değişikliği tüm uygulamaya bildiriyoruz ki ilgili ekranlar kendilerini güncellesin.
        var affectedCategoryIDs: Set<UUID> = []
        if let kategoriID = islem.kategori?.id {
            affectedCategoryIDs.insert(kategoriID)
        }

        // Yeni payload'ı oluştur
        let payload = TransactionChangePayload(
            type: .delete,
            affectedAccountIDs: Array(affectedAccountIDs),
            affectedCategoryIDs: Array(affectedCategoryIDs)
        )
        
        // Bildirimi yeni payload ile gönder
        NotificationCenter.default.post(
            name: .transactionsDidChange,
            object: nil,
            userInfo: ["payload": payload] // userInfo sözlüğünü payload'ı içerecek şekilde güncelledik
        )
    }
}
