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
        do {
            var affectedAccountIDs: Set<UUID> = []
            var affectedCategoryIDs: Set<UUID> = []
            
            // İlişkili ID'leri güvenli şekilde topla
            if let hesapID = islem.hesap?.id {
                affectedAccountIDs.insert(hesapID)
            }
            if let kategoriID = islem.kategori?.id {
                affectedCategoryIDs.insert(kategoriID)
            }
            
            // İşlemi sil
            context.delete(islem)
            
            // Kaydet
            try context.save()
            
            // Bildirim gönder
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
            
            Logger.log("İşlem başarıyla silindi: \(islem.id)", log: Logger.service)
            
        } catch {
            Logger.log("İşlem silme hatası: \(error)", log: Logger.service, type: .error)
        }
    }
    
    /// Bir işlemin ait olduğu seriyi arka planda, UI'ı bloklamadan siler ve işlem bittiğinde bildirim yayınlar.
    @MainActor
    func deleteSeriesInBackground(tekrarID: UUID, from modelContainer: ModelContainer) async {
        guard tekrarID != UUID() else { return }
        
        do {
            let backgroundContext = ModelContext(modelContainer)
            backgroundContext.autosaveEnabled = false // Otomatik kaydetmeyi kapat
            
            let predicate = #Predicate<Islem> { $0.tekrarID == tekrarID }
            let descriptor = FetchDescriptor(predicate: predicate)
            
            let itemsToDelete = try backgroundContext.fetch(descriptor)
            guard !itemsToDelete.isEmpty else { return }
            
            // Batch silme için ID'leri topla
            var affectedAccountIDs: Set<UUID> = []
            var affectedCategoryIDs: Set<UUID> = []
            
            for item in itemsToDelete {
                if let hesapID = item.hesap?.id {
                    affectedAccountIDs.insert(hesapID)
                }
                if let kategoriID = item.kategori?.id {
                    affectedCategoryIDs.insert(kategoriID)
                }
                backgroundContext.delete(item)
            }
            
            // Toplu kaydet
            try backgroundContext.save()
            
            Logger.log("Seri silindi: \(itemsToDelete.count) işlem", log: Logger.service)
            
            // Ana thread'de bildirim gönder
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
            Logger.log("Seri silme hatası: \(error)", log: Logger.service, type: .error)
        }
    }
}
