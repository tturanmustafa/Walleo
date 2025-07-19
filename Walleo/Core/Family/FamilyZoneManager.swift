//
//  FamilyZoneManager.swift
//  Walleo
//
//  Created by Mustafa Turan on 19.07.2025.
//


// Walleo/Core/Services/FamilyZoneManager.swift

import Foundation
import CloudKit

class FamilyZoneManager {
    // Uygulama genelinde kullanacağımız sabit zone adı
    static let zoneName = "FamilyZone"
    
    // Uygulama genelinde kullanacağımız sabit zone ID
    static let zoneID = CKRecordZone.ID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName)
    
    private let database: CKDatabase
    
    init(database: CKDatabase) {
        self.database = database
    }
    
    // Bu fonksiyon, özel bölgemizin CloudKit'te var olup olmadığını kontrol eder,
    // Walleo/Core/Services/FamilyZoneManager.swift dosyasındaki
    // createZoneIfNeeded fonksiyonunun DOĞRU hali

    func createZoneIfNeeded() async throws {
        // Mevcut zone'ları kontrol et
        let allZones = try await database.allRecordZones()
        if allZones.contains(where: { $0.zoneID == Self.zoneID }) {
            // Zone zaten var, bir şey yapmaya gerek yok.
            Logger.log("FamilyZone zaten mevcut.", log: Logger.service, type: .info)
            return
        }
        
        // Zone yok, yeni bir tane oluştur.
        Logger.log("FamilyZone mevcut değil, oluşturuluyor...", log: Logger.service, type: .info)
        let newZone = CKRecordZone(zoneID: Self.zoneID)
        
        // DÜZELTME: Hata veren bu satır kaldırıldı. Paylaşım yeteneği,
        // bu zone'a bir CKShare kaydedildiğinde sunucu tarafında otomatik olarak etkinleştirilir.
        // newZone.capabilities = [.sharing]  <-- BU SATIRI SİLİN
        
        try await database.save(newZone)
        Logger.log("FamilyZone başarıyla oluşturuldu.", log: Logger.service, type: .info)
    }
}
