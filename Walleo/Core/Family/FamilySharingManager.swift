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
        let userRecord = try await privateDatabase.record(for: userID)
        
        // Kullanıcı adını al
        if let userIdentity = try? await container.userIdentity(forUserRecordID: userID) {
            let name = userIdentity.nameComponents?.givenName ?? "Kullanıcı"
            return (userID.recordName, name)
        }
        
        return (userID.recordName, "Kullanıcı")
    }
    
    // MARK: - Aile Oluşturma
    func createFamily(name: String, in modelContext: ModelContext) async throws {
        isLoadingFamily = true
        defer { isLoadingFamily = false }
        
        let (userID, userName) = try await fetchCurrentUser()
        
        // Aile modelini oluştur
        let aile = Aile(isim: name, sahipID: userID, sahipAdi: userName)
        
        // Sahip olan kullanıcıyı üye olarak ekle
        let sahipUye = AileUyesi(userID: userID, adi: userName, davetDurumu: DavetDurumu.kabul)
        sahipUye.aile = aile
        aile.uyeler?.append(sahipUye)
        
        modelContext.insert(aile)
        modelContext.insert(sahipUye)
        
        try modelContext.save()
        
        self.currentFamily = aile
        self.familyMembers = [sahipUye]
        
        Logger.logFamilyAction("FAMILY_CREATED", details: [
            "familyID": aile.id.uuidString,
            "familyName": name,
            "ownerID": userID
        ])
    }
    
    // MARK: - Aile Üyesi Davet Etme
    func inviteMember(to family: Aile, in modelContext: ModelContext) async throws -> CKShare {
        // CloudKit record oluştur
        let familyRecord = CKRecord(recordType: "Family", recordID: CKRecord.ID(recordName: family.id.uuidString))
        familyRecord["name"] = family.isim
        familyRecord["ownerID"] = family.sahipID
        familyRecord["createdAt"] = family.olusturmaTarihi
        
        // Share oluştur
        let share = CKShare(rootRecord: familyRecord)
        share[CKShare.SystemFieldKey.title] = "\(family.isim) Aile Hesabı"
        share[CKShare.SystemFieldKey.shareType] = "com.walleo.family"
        share.publicPermission = .none
        
        // Kaydet
        let operation = CKModifyRecordsOperation(recordsToSave: [familyRecord, share], recordIDsToDelete: nil)
        operation.modifyRecordsResultBlock = { result in
            switch result {
            case .success:
                Task { @MainActor in
                    family.shareRecordID = share.recordID.recordName
                    try? modelContext.save()
                }
            case .failure(let error):
                Logger.logFamilyAction("SHARE_CREATE_FAILED", details: ["error": error.localizedDescription], type: .error)
            }
        }
        
        try await privateDatabase.add(operation)
        
        Logger.logFamilyAction("MEMBER_INVITED", details: [
            "familyID": family.id.uuidString,
            "shareID": share.recordID.recordName
        ])
        
        return share
    }
    
    // MARK: - Davet Kabul Etme
    func acceptInvitation(_ shareMetadata: CKShare.Metadata) async throws {
        let operation = CKAcceptSharesOperation(shareMetadatas: [shareMetadata])
        operation.perShareResultBlock = { metadata, result in
            switch result {
            case .success(let share):
                Logger.logFamilyAction("INVITATION_ACCEPTED", details: [
                    "shareID": share.recordID.recordName
                ])
            case .failure(let error):
                Logger.logFamilyAction("INVITATION_ACCEPT_FAILED", details: [
                    "error": error.localizedDescription
                ], type: .error)
            }
        }
        
        try await container.add(operation)
    }
    
    // MARK: - Aile Verilerini Yükle
    func loadFamilyData(in modelContext: ModelContext) async {
        isLoadingFamily = true
        defer { isLoadingFamily = false }
        
        do {
            // Mevcut aileyi kontrol et
            let descriptor = FetchDescriptor<Aile>()
            if let existingFamily = try modelContext.fetch(descriptor).first {
                self.currentFamily = existingFamily
                self.familyMembers = existingFamily.uyeler ?? []
                
                // CloudKit'ten güncellemeleri kontrol et
                await syncFamilyData(family: existingFamily, in: modelContext)
            }
        } catch {
            Logger.logFamilyAction("LOAD_FAMILY_FAILED", details: [
                "error": error.localizedDescription
            ], type: .error)
        }
    }
    
    // MARK: - Senkronizasyon
    private func syncFamilyData(family: Aile, in modelContext: ModelContext) async {
        guard let shareRecordID = family.shareRecordID else { return }
        
        do {
            let shareRecord = CKRecord.ID(recordName: shareRecordID)
            let share = try await sharedDatabase.record(for: shareRecord) as? CKShare
            
            // Participants'ları güncelle
            if let participants = share?.participants {
                for participant in participants {
                    if participant.acceptanceStatus == .accepted {
                        // Üye zaten varsa güncelle, yoksa ekle
                        let userID = participant.userIdentity.userRecordID?.recordName ?? ""
                        if !familyMembers.contains(where: { $0.userID == userID }) {
                            let newMember = AileUyesi(
                                userID: userID,
                                adi: participant.userIdentity.nameComponents?.givenName ?? "Üye",
                                davetDurumu: DavetDurumu.kabul
                            )
                            newMember.aile = family
                            modelContext.insert(newMember)
                            familyMembers.append(newMember)
                        }
                    }
                }
                try modelContext.save()
            }
        } catch {
            Logger.logFamilyAction("SYNC_FAMILY_FAILED", details: [
                "error": error.localizedDescription
            ], type: .error)
        }
    }
    
    // MARK: - Aile'den Ayrılma
    func leaveFamily(_ family: Aile, in modelContext: ModelContext) async throws {
        let (currentUserID, _) = try await fetchCurrentUser()
        
        // Kullanıcıyı ailede bul ve sil
        if let memberToRemove = family.uyeler?.first(where: { $0.userID == currentUserID }) {
            modelContext.delete(memberToRemove)
        }
        
        // Eğer son üyeyse aileyi de sil
        if family.uyeler?.count == 1 {
            modelContext.delete(family)
        }
        
        try modelContext.save()
        
        self.currentFamily = nil
        self.familyMembers = []
        
        Logger.logFamilyAction("LEFT_FAMILY", details: [
            "familyID": family.id.uuidString,
            "userID": currentUserID
        ])
    }
}
