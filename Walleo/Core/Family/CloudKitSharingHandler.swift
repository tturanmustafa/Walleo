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
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              components.host == "share" else {
            return false
        }
        
        Task {
            do {
                let container = CKContainer(identifier: "iCloud.com.mustafamt.walleo")
                let metadata = try await container.shareMetadata(for: url)
                
                await MainActor.run {
                    self.presentingShareMetadata = ShareMetadataWrapper(metadata: metadata)
                }
                
                return true
            } catch {
                Logger.log("Failed to fetch share metadata: \(error)", log: Logger.service, type: .error)
                return false
            }
        }
        
        return true
    }
}
