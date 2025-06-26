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
    
    static let shared = TransactionService()
    private init() {}
    
    /// Tek bir işlemi veritabanından siler ve ilgili ekranların güncellenmesi için bildirim yayınlar.
    /// Bu fonksiyon ana iş parçacığında çalışır ve tekil, hızlı silmeler için uygundur.
    func deleteTransaction(_ islem: Islem, in context: ModelContext) {
        var affectedAccountIDs: Set<UUID> = []
        if let hesapID = islem.hesap?.id {
            affectedAccountIDs.insert(hesapID)
        }
        
        var affectedCategoryIDs: Set<UUID> = []
        if let kategoriID = islem.kategori?.id {
            affectedCategoryIDs.insert(kategoriID)
        }
        
        context.delete(islem)
        try? context.save() // Değişikliğin kaydedildiğinden emin oluyoruz.

        let payload = TransactionChangePayload(
            type: .delete,
            affectedAccountIDs: Array(affectedAccountIDs),
            affectedCategoryIDs: Array(affectedCategoryIDs)
        )
        
        NotificationCenter.default.post(
            name: .transactionsDidChange,
            object: nil,
            userInfo: ["payload": payload]
        )
        Logger.log("TransactionService: Tek bir işlem silindi ve bildirim gönderildi. ID: \(islem.id)", log: Logger.service)
    }
    
    /// Bir işlemin ait olduğu seriyi arka planda, UI'ı bloklamadan siler ve işlem bittiğinde bildirim yayınlar.
    @MainActor
    func deleteSeriesInBackground(tekrarID: UUID, from modelContainer: ModelContainer) async {
        guard tekrarID != UUID() else { return }
        
        // Arka planda çalışacak yeni bir context oluşturuyoruz.
        let backgroundContext = ModelContext(modelContainer)
        let predicate = #Predicate<Islem> { $0.tekrarID == tekrarID }
        let descriptor = FetchDescriptor(predicate: predicate)
        
        do {
            // 1. Adım: Silinecek tüm işlemleri arka planda bul.
            let itemsToDelete = try backgroundContext.fetch(descriptor)
            
            // Eğer silinecek bir şey yoksa işlemi sonlandır.
            guard !itemsToDelete.isEmpty else { return }
            
            // 2. Adım: Payload için etkilenecek tüm hesap ve kategori ID'lerini topla.
            var affectedAccountIDs: Set<UUID> = []
            var affectedCategoryIDs: Set<UUID> = []
            
            for item in itemsToDelete {
                if let hesapID = item.hesap?.id {
                    affectedAccountIDs.insert(hesapID)
                }
                if let kategoriID = item.kategori?.id {
                    affectedCategoryIDs.insert(kategoriID)
                }
            }
            
            // 3. Adım: Bulunan işlemleri sil ve veritabanını kaydet.
            try backgroundContext.delete(model: Islem.self, where: predicate)
            try backgroundContext.save()
            
            Logger.log("TransactionService: Seri arka planda silindi. TekrarID: \(tekrarID)", log: Logger.service, type: .info)
            
            // 4. Adım: Ana iş parçacığına geri dönüp bildirimi gönder.
            let payload = TransactionChangePayload(
                type: .delete,
                affectedAccountIDs: Array(affectedAccountIDs),
                affectedCategoryIDs: Array(affectedCategoryIDs)
            )
            
            NotificationCenter.default.post(
                name: .transactionsDidChange,
                object: nil,
                userInfo: ["payload": payload]
            )
            
        } catch {
            Logger.log("TransactionService: Seri arka planda silinirken hata oluştu: \(error.localizedDescription)", log: Logger.service, type: .error)
        }
    }
}
