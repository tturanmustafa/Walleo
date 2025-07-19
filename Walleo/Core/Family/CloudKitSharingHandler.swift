// Walleo/Core/Services/CloudKitSharingHandler.swift

import SwiftUI
import CloudKit

// Wrapper yapı - CKShare.Metadata'yı Identifiable yapmak için
struct ShareMetadataWrapper: Identifiable {
    let id = UUID()
    let metadata: CKShare.Metadata
}

class CloudKitSharingHandler: ObservableObject {
    static let shared = CloudKitSharingHandler()
    
    @Published var presentingShareMetadata: ShareMetadataWrapper?
    
    private init() {}
    
    func handleURL(_ url: URL) -> Bool {
        // DÜZELTME: Hatalı olan host kontrolü kaldırıldı.
        // CloudKit paylaşım URL'sini doğrulamanın en güvenli yolu
        // doğrudan Apple'ın sunucusundan metadata'yı sorgulamaktır.
        // Aşağıdaki `container.shareMetadata(for: url)` çağrısı bu işi zaten yapıyor.
        // Bu yüzden baştaki guard kontrolü hem hatalı hem de gereksizdi.
        
        Task {
            do {
                let container = CKContainer(identifier: "iCloud.com.mustafamt.walleo")
                let metadata = try await container.shareMetadata(for: url)
                
                // Başarıyla metadata alındıysa, bu geçerli bir paylaşım URL'sidir.
                // Şimdi bunu UI'da göstermek için ana thread'e geçelim.
                await MainActor.run {
                    self.presentingShareMetadata = ShareMetadataWrapper(metadata: metadata)
                }
                
            } catch {
                Logger.log("Paylaşım metadata'sı alınamadı: \(error)", log: Logger.service, type: .error)
            }
        }
        
        // Görevin asenkron olarak ele alınacağını sisteme bildirmek için true dönüyoruz.
        return true
    }
}
