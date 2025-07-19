// Walleo/Core/Services/FamilySharingManager.swift

import Foundation
import CloudKit
import SwiftData
import UIKit

@MainActor
class FamilySharingManager: ObservableObject {
    static let shared = FamilySharingManager()
    
    @Published var currentFamily: Aile?
    @Published var isLoadingFamily = false
    @Published var familyMembers: [AileUyesi] = []
    @Published var pendingInvitations: [AileDavet] = []
    
    private let container = CKContainer(identifier: "iCloud.com.mustafamt.walleo")
    private let privateDatabase: CKDatabase
    private let sharedDatabase: CKDatabase
    
    private init() {
        self.privateDatabase = container.privateCloudDatabase
        self.sharedDatabase = container.sharedCloudDatabase
    }
    
    // MARK: - Kullanıcı Bilgisi
    func fetchCurrentUser() async throws -> (userID: String, userName: String) {
        let userID = try await container.userRecordID()
        let identity = try await container.userIdentities(forUserRecordIDs: [userID]).first?.value
        let name = identity?.nameComponents?.givenName ?? "Kullanıcı"
        return (userID.recordName, name)
    }
    
    // MARK: - Aile Oluşturma
    func createFamily(name: String, in modelContext: ModelContext) async throws {
        // ... (Bu fonksiyonda değişiklik yok)
        isLoadingFamily = true
        defer { isLoadingFamily = false }
        
        let (userID, userName) = try await fetchCurrentUser()
        
        let aile = Aile(isim: name, sahipID: userID, sahipAdi: userName)
        
        let sahipUye = AileUyesi(userID: userID, adi: userName, davetDurumu: DavetDurumu.kabul)
        sahipUye.aile = aile
        aile.uyeler?.append(sahipUye)
        
        modelContext.insert(aile)
        modelContext.insert(sahipUye)
        
        try modelContext.save()
        
        self.currentFamily = aile
        self.familyMembers = [sahipUye]
        
        Logger.logFamilyAction("FAMILY_CREATED", details: ["familyID": aile.id.uuidString, "familyName": name, "ownerID": userID])
    }
    
    // MARK: - Aile Üyesi Davet Etme
    // DÜZELTME 1: Bu fonksiyon artık mevcut bir davet varsa onu getiriyor, yoksa yeni oluşturuyor.
    func inviteMember(to family: Aile, in modelContext: ModelContext) async throws -> CKShare {
        // Eğer aile için daha önce bir paylaşım oluşturulmuşsa, onu yeniden oluşturmak yerine bul ve getir.
        if let existingShareRecordName = family.shareRecordID {
            let recordID = CKRecord.ID(recordName: existingShareRecordName, zoneID: FamilyZoneManager.zoneID)
            do {
                if let existingShare = try await privateDatabase.record(for: recordID) as? CKShare {
                    Logger.logFamilyAction("FETCHED_EXISTING_SHARE", details: ["shareID": existingShare.recordID.recordName])
                    return existingShare
                }
            } catch {
                // Eğer bir sebepten ötürü eski kayıt bulunamazsa, logla ve yeni oluşturmaya devam et.
                Logger.logFamilyAction("EXISTING_SHARE_FETCH_FAILED", details: ["error": error.localizedDescription], type: .error)
            }
        }
        
        // Mevcut bir paylaşım yoksa veya bulunamadıysa, yeni bir tane oluştur.
        let familyRecordID = CKRecord.ID(recordName: family.id.uuidString, zoneID: FamilyZoneManager.zoneID)
        let familyRecord = CKRecord(recordType: "CD_Aile", recordID: familyRecordID)
        
        familyRecord["name"] = family.isim as CKRecordValue
        familyRecord["ownerID"] = family.sahipID as CKRecordValue
        familyRecord["createdAt"] = family.olusturmaTarihi as CKRecordValue
        
        let share = CKShare(rootRecord: familyRecord)
        share[CKShare.SystemFieldKey.title] = "\(family.isim) Aile Hesabı" as CKRecordValue
        share.publicPermission = .none
        
        do {
            let zoneManager = FamilyZoneManager(database: privateDatabase)
            try await zoneManager.createZoneIfNeeded()
            let (saveResults, _) = try await privateDatabase.modifyRecords(saving: [familyRecord, share], deleting: [])
            
            if let shareResult = saveResults[share.recordID] {
                switch shareResult {
                case .success(let savedRecord):
                    if let savedShare = savedRecord as? CKShare {
                        Logger.logFamilyAction("NEW_MEMBER_INVITED_AND_SAVED", details: ["familyID": family.id.uuidString, "shareID": savedShare.recordID.recordName])
                        family.shareRecordID = savedShare.recordID.recordName
                        try modelContext.save()
                        return savedShare
                    } else { throw NSError(domain: "FamilySharingManager", code: 3, userInfo: [NSLocalizedDescriptionKey: "Sunucudan dönen kayıt bir paylaşım nesnesi değil."]) }
                case .failure(let error): throw error
                }
            } else { throw NSError(domain: "FamilySharingManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Sunucu, paylaşım nesnesi için bir sonuç döndürmedi."]) }
        } catch {
            Logger.logFamilyAction("MODIFY_RECORDS_OPERATION_FAILED", details: ["error": error.localizedDescription], type: .error)
            throw error
        }
    }
    
    // MARK: - Davet Kabul Etme
    func acceptInvitation(_ shareMetadata: CKShare.Metadata) async throws {
        // ... (Bu fonksiyonda değişiklik yok)
        do {
            let acceptedShare = try await container.accept(shareMetadata)
            Logger.logFamilyAction("INVITATION_ACCEPTED", details: ["shareID": acceptedShare.recordID.recordName])
        } catch {
            Logger.logFamilyAction("INVITATION_ACCEPT_FAILED", details: ["error": error.localizedDescription], type: .error)
            throw error
        }
    }
    
    // MARK: - Aile Verilerini Yükle
    func loadFamilyData(in modelContext: ModelContext) async {
        // ... (Bu fonksiyonda değişiklik yok)
        isLoadingFamily = true
        defer { isLoadingFamily = false }
        
        do {
            let descriptor = FetchDescriptor<Aile>()
            if let existingFamily = try modelContext.fetch(descriptor).first {
                self.currentFamily = existingFamily
                self.familyMembers = existingFamily.uyeler ?? []
                await syncFamilyData(family: existingFamily, in: modelContext)
            }
        } catch {
            Logger.logFamilyAction("LOAD_FAMILY_FAILED", details: ["error": error.localizedDescription], type: .error)
        }
    }
    
    // MARK: - Senkronizasyon
    private func syncFamilyData(family: Aile, in modelContext: ModelContext) async {
        guard let shareRecordName = family.shareRecordID else { return }
        
        do {
            // DÜZELTME 2: CKRecord.ID oluşturulurken doğru zoneID (FamilyZone) belirtiliyor.
            let shareRecordID = CKRecord.ID(recordName: shareRecordName, zoneID: FamilyZoneManager.zoneID)
            
            // Not: Paylaşılan kayıtlar `privateDatabase` yerine `sharedDatabase`'den çekilir.
            guard let share = try await sharedDatabase.record(for: shareRecordID) as? CKShare else { return }
            
            for participant in share.participants {
                if participant.acceptanceStatus == .accepted {
                    let userID = participant.userIdentity.userRecordID?.recordName ?? ""
                    if !familyMembers.contains(where: { $0.userID == userID }) {
                        let newMember = AileUyesi(userID: userID, adi: participant.userIdentity.nameComponents?.givenName ?? "Üye", davetDurumu: DavetDurumu.kabul)
                        newMember.aile = family
                        modelContext.insert(newMember)
                        familyMembers.append(newMember)
                    }
                }
            }
            try modelContext.save()
        } catch {
            Logger.logFamilyAction("SYNC_FAMILY_FAILED", details: ["error": error.localizedDescription], type: .error)
        }
    }
    
    // MARK: - Aile'den Ayrılma
    func leaveFamily(_ family: Aile, in modelContext: ModelContext) async throws {
        // ... (Bu fonksiyonda değişiklik yok)
        let (currentUserID, _) = try await fetchCurrentUser()
        
        if let memberToRemove = family.uyeler?.first(where: { $0.userID == currentUserID }) {
            modelContext.delete(memberToRemove)
        }
        
        if family.uyeler?.count == 1 {
            modelContext.delete(family)
        }
        
        try modelContext.save()
        
        self.currentFamily = nil
        self.familyMembers = []
        
        Logger.logFamilyAction("LEFT_FAMILY", details: ["familyID": family.id.uuidString, "userID": currentUserID])
    }
}
