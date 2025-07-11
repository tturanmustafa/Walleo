import Foundation
import CloudKit
import SwiftData

@MainActor
class CloudKitManager: ObservableObject {
    static let shared = CloudKitManager()
    
    private let container = CKContainer(identifier: "iCloud.com.mustafamt.walleo")
    private let privateDB: CKDatabase
    private let sharedDB: CKDatabase
    
    @Published var isAvailable = false
    @Published var currentUserID: String?
    
    private init() {
        self.privateDB = container.privateCloudDatabase
        self.sharedDB = container.sharedCloudDatabase
        
        Task {
            await checkAvailability()
        }
    }
    
    // MARK: - Setup
    
    func checkAvailability() async {
        do {
            let status = try await container.accountStatus()
            isAvailable = status == .available
            
            if isAvailable {
                let userID = try await container.userRecordID()
                currentUserID = userID.recordName
            }
        } catch {
            Logger.log("CloudKit availability check failed: \(error)", log: Logger.service, type: .error)
            isAvailable = false
        }
    }
    
    // MARK: - User Discovery
    
    func discoverUser(email: String) async throws -> (userID: String, displayName: String) {
        // Önce permission kontrolü yap
        let permissionStatus = try await container.applicationPermissionStatus(for: .userDiscoverability)
        
        if permissionStatus != .granted {
            // Permission yoksa request et
            let requestedStatus = try await container.requestApplicationPermission(.userDiscoverability)
            if requestedStatus != .granted {
                throw AileHataları.kullaniciIDYok
            }
        }
        
        do {
            let userIdentity = try await container.userIdentity(forEmailAddress: email)
            
            guard let recordID = userIdentity?.userRecordID else {
                throw AileHataları.kullaniciIDYok
            }
            
            let displayName = [
                userIdentity?.nameComponents?.givenName,
                userIdentity?.nameComponents?.familyName
            ].compactMap { $0 }.joined(separator: " ")
            
            return (recordID.recordName, displayName.isEmpty ? email : displayName)
        } catch {
            Logger.log("User discovery failed: \(error)", log: Logger.service, type: .error)
            throw AileHataları.kullaniciIDYok
        }
    }
    
    // MARK: - Share Management
    
    func createShare(for familyRecord: CKRecord) async throws -> CKShare {
        let share = CKShare(rootRecord: familyRecord)
        share[CKShare.SystemFieldKey.title] = familyRecord["isim"] as? String ?? "Aile Hesabı"
        share.publicPermission = .none
        
        do {
            let (savedRecords, _) = try await sharedDB.modifyRecords(
                saving: [familyRecord, share],
                deleting: []
            )
            
            guard let finalShare = savedRecords.first(where: { $0 is CKShare }) as? CKShare else {
                throw AileHataları.contextYok
            }
            
            return finalShare
        } catch {
            Logger.log("Share creation failed: \(error)", log: Logger.service, type: .error)
            throw error
        }
    }
    
    // MARK: - Data Operations
    
    func saveRecord(_ record: CKRecord, to database: CKDatabase? = nil) async throws {
        let db = database ?? privateDB
        _ = try await db.save(record)
    }
    
    func fetchRecords(ofType type: String, predicate: NSPredicate = NSPredicate(value: true), from database: CKDatabase? = nil) async throws -> [CKRecord] {
        let db = database ?? privateDB
        let query = CKQuery(recordType: type, predicate: predicate)
        
        let (matchResults, _) = try await db.records(matching: query)
        
        var records: [CKRecord] = []
        for (_, result) in matchResults {
            if case .success(let record) = result {
                records.append(record)
            }
        }
        
        return records
    }
    
    func deleteRecord(_ recordID: CKRecord.ID, from database: CKDatabase? = nil) async throws {
        let db = database ?? privateDB
        _ = try await db.deleteRecord(withID: recordID)
    }
}

