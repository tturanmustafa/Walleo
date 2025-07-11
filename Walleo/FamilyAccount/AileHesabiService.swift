import Foundation
import SwiftData
import CloudKit

@MainActor
class AileHesabiService: ObservableObject {
    static let shared = AileHesabiService()
    
    @Published var mevcutAileHesabi: AileHesabi?
    @Published var bekleyenDavetler: [AileDavet] = []
    @Published var adminDavetleri: [AileDavet] = []
    @Published var isProcessing = false
    @Published var currentOperation: String?
    @Published var familyShare: CKShare?
    
    private var modelContext: ModelContext?
    private let cloudKit = CloudKitManager.shared
    private let maxUyeSayisi = 4
    
    private init() {
        // iCloud durum değişikliklerini dinle
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(iCloudStatusChanged),
            name: .iCloudStatusChanged,
            object: nil
        )
    }
    
    @objc private func iCloudStatusChanged() {
        Task {
            await kontrolEt()
        }
    }
    
    func configure(with modelContext: ModelContext) {
        self.modelContext = modelContext
        Task {
            await kontrolEt()
        }
    }
    
    // MARK: - Aile Hesabı İşlemleri
    
    func aileHesabiOlustur(isim: String) async throws {
        guard let modelContext = modelContext else { throw AileHataları.contextYok }
        guard let currentUserID = cloudKit.currentUserID else { throw AileHataları.kullaniciIDYok }
        
        // iCloud kontrolü
        guard cloudKit.isAvailable else { throw AileHataları.iCloudGerekli }
        
        isProcessing = true
        currentOperation = "family.creating"
        
        Logger.logFamilyAction("CREATE_FAMILY_START", details: ["name": isim])
        
        do {
            // Mevcut aile hesabı kontrolü
            if mevcutAileHesabi != nil {
                throw AileHataları.zatenAileHesabiVar
            }
            
            // Yeni aile hesabı oluştur
            let yeniAileHesabi = AileHesabi(isim: isim, adminID: currentUserID)
            
            // Admin'i üye olarak ekle
            let adminUye = AileUyesi(
                appleID: currentUserID,
                gorunumIsmi: "Admin",
                durum: .aktif
            )
            adminUye.aileHesabi = yeniAileHesabi
            
            modelContext.insert(yeniAileHesabi)
            modelContext.insert(adminUye)
            
            try modelContext.save()
            mevcutAileHesabi = yeniAileHesabi
            
            Logger.logFamilyAction("CREATE_FAMILY_SUCCESS", details: ["familyID": yeniAileHesabi.id.uuidString])
            
        } catch {
            isProcessing = false
            currentOperation = nil
            Logger.logFamilyAction("CREATE_FAMILY_ERROR", details: ["error": error.localizedDescription], type: .error)
            throw error
        }
        
        isProcessing = false
        currentOperation = nil
    }
    
    func aileHesabiniSil() async throws {
        guard let modelContext = modelContext else { throw AileHataları.contextYok }
        guard let aileHesabi = mevcutAileHesabi else { throw AileHataları.aileHesabiYok }
        guard let currentUserID = cloudKit.currentUserID else { throw AileHataları.kullaniciIDYok }
        
        // Admin kontrolü
        guard aileHesabi.adminID == currentUserID else {
            throw AileHataları.yetkiYok
        }
        
        isProcessing = true
        currentOperation = "family.deleting"
        
        do {
            Logger.logFamilyAction("DELETE_FAMILY_START", details: ["familyID": aileHesabi.id.uuidString, "memberCount": aileHesabi.uyeler?.count ?? 0])
            
            // Tüm üyeleri sil
            if let uyeler = aileHesabi.uyeler {
                for uye in uyeler {
                    modelContext.delete(uye)
                }
            }
            
            // Aile hesabını sil
            modelContext.delete(aileHesabi)
            
            try modelContext.save()
            mevcutAileHesabi = nil
            
            Logger.logFamilyAction("DELETE_FAMILY_SUCCESS")
            
        } catch {
            isProcessing = false
            currentOperation = nil
            Logger.logFamilyAction("DELETE_FAMILY_ERROR", details: ["error": error.localizedDescription], type: .error)
            throw error
        }
        
        isProcessing = false
        currentOperation = nil
    }
    
    func aileHesabiniDuzenle(yeniIsim: String) async throws {
        guard let modelContext = modelContext else { throw AileHataları.contextYok }
        guard let aileHesabi = mevcutAileHesabi else { throw AileHataları.aileHesabiYok }
        guard let currentUserID = cloudKit.currentUserID else { throw AileHataları.kullaniciIDYok }
        
        // Admin kontrolü
        guard aileHesabi.adminID == currentUserID else {
            throw AileHataları.yetkiYok
        }
        
        aileHesabi.isim = yeniIsim
        aileHesabi.guncellemeTarihi = Date()
        
        try modelContext.save()
        
        Logger.logFamilyAction("EDIT_FAMILY_NAME", details: ["newName": yeniIsim])
    }
    
    func uyeEkle(email: String, gorunumIsmi: String) async throws {
        guard let aileHesabi = mevcutAileHesabi else { throw AileHataları.aileHesabiYok }
        guard let currentUserID = cloudKit.currentUserID else { throw AileHataları.kullaniciIDYok }
        guard let modelContext = modelContext else { throw AileHataları.contextYok }
        
        Logger.logFamilyAction("ADD_MEMBER_START", details: ["email": email, "displayName": gorunumIsmi])
        
        // Admin kontrolü
        guard aileHesabi.adminID == currentUserID else {
            throw AileHataları.yetkiYok
        }
        
        // Üye sayısı kontrolü
        let mevcutUyeSayisi = aileHesabi.uyeler?.count ?? 0
        guard mevcutUyeSayisi < maxUyeSayisi else {
            throw AileHataları.maksimumUyeSayisi
        }
        
        // Email'in zaten davet edilip edilmediğini kontrol et
        let existingInvite = adminDavetleri.first { davet in
            let emailMatch = davet.davetEdilenID == "pending_\(email)" ||
                           davet.gorunumIsmi?.lowercased() == email.lowercased()
            return emailMatch && davet.durum == .beklemede
        }
        
        if existingInvite != nil {
            throw AileHataları.zaatenDavetEdilmis
        }
        
        // Email'in zaten üye olup olmadığını kontrol et
        if let uyeler = aileHesabi.uyeler {
            let emailAlreadyMember = uyeler.contains { uye in
                uye.gorunumIsmi.lowercased().contains(email.lowercased())
            }
            if emailAlreadyMember {
                throw AileHataları.zaatenUye
            }
        }
        
        isProcessing = true
        currentOperation = "family.inviting"
        
        do {
            // Önce kullanıcıyı bulmayı dene
            var userID: String
            var displayName: String
            
            do {
                let userInfo = try await cloudKit.discoverUser(email: email)
                userID = userInfo.userID
                displayName = userInfo.displayName
                Logger.logFamilyAction("USER_DISCOVERED", details: ["userID": userID, "displayName": displayName])
            } catch {
                // User discovery başarısız olursa, geçici bir ID oluştur
                Logger.logFamilyAction("USER_DISCOVERY_FAILED", details: ["email": email, "error": error.localizedDescription], type: .error)
                userID = "pending_\(email)"
                displayName = gorunumIsmi
            }
            
            // Davet oluştur
            let davet = AileDavet(
                aileHesabiID: aileHesabi.id,
                aileHesabiIsmi: aileHesabi.isim,
                davetEdenID: currentUserID,
                davetEdenIsim: "Admin",
                davetEdilenID: userID,
                gorunumIsmi: displayName
            )
            
            modelContext.insert(davet)
            try modelContext.save()
            
            Logger.logFamilyAction("INVITE_SENT_SUCCESS", details: ["inviteID": davet.id.uuidString])
            
            // Davet listesini güncelle
            await kontrolEt()
            
        } catch {
            isProcessing = false
            currentOperation = nil
            Logger.logFamilyAction("ADD_MEMBER_ERROR", details: ["error": error.localizedDescription], type: .error)
            throw error
        }
        
        isProcessing = false
        currentOperation = nil
    }
    
    func daveteYanitVer(davet: AileDavet, kabul: Bool, veriSecenegi: VeriSecenegi = .temizBaslangic) async throws {
        guard let modelContext = modelContext else { throw AileHataları.contextYok }
        guard let currentUserID = cloudKit.currentUserID else { throw AileHataları.kullaniciIDYok }
        
        // Davetin hala geçerli olduğunu kontrol et
        guard davet.durum == .beklemede else {
            throw AileHataları.davetGecersiz
        }
        
        guard davet.gecerlilikTarihi > Date() else {
            throw AileHataları.davetSuresiDolmus
        }
        
        isProcessing = true
        currentOperation = kabul ? "family.joining" : "family.declining"
        
        Logger.logFamilyAction(kabul ? "ACCEPT_INVITE_START" : "DECLINE_INVITE",
                              details: ["inviteID": davet.id.uuidString, "dataOption": veriSecenegi])
        
        do {
            if kabul {
                // Zaten bir aile hesabı var mı kontrol et
                if mevcutAileHesabi != nil {
                    throw AileHataları.zatenAileHesabiVar
                }
                
                // Aile hesabını bul veya oluştur
                let aileHesabiID = davet.aileHesabiID
                let descriptor = FetchDescriptor<AileHesabi>(
                    predicate: #Predicate { hesap in
                        hesap.id == aileHesabiID
                    }
                )
                
                if let aileHesabi = try modelContext.fetch(descriptor).first {
                    // Veri işlemleri
                    if veriSecenegi == .temizBaslangic {
                        // Mevcut verileri sil
                        try await clearUserData()
                    } else {
                        // Mevcut verileri aileye dahil et
                        try await mergeDataToFamily(aileHesabi: aileHesabi)
                    }
                    
                    // Yeni üye ekle
                    let yeniUye = AileUyesi(
                        appleID: currentUserID,
                        gorunumIsmi: davet.gorunumIsmi ?? "Üye",
                        durum: .aktif
                    )
                    yeniUye.aileHesabi = aileHesabi
                    modelContext.insert(yeniUye)
                    
                    mevcutAileHesabi = aileHesabi
                    
                    // Diğer bekleyen davetleri otomatik reddet
                    await otomatikDavetReddi(kullaniciID: currentUserID)
                    
                } else {
                    throw AileHataları.aileHesabiYok
                }
            }
            
            // Daveti güncelle
            davet.durum = kabul ? .kabul : .red
            try modelContext.save()
            
            Logger.logFamilyAction(kabul ? "ACCEPT_INVITE_SUCCESS" : "DECLINE_INVITE_SUCCESS")
            
            // Listeleri güncelle
            await kontrolEt()
            
        } catch {
            isProcessing = false
            currentOperation = nil
            Logger.logFamilyAction("INVITE_RESPONSE_ERROR", details: ["error": error.localizedDescription], type: .error)
            throw error
        }
        
        isProcessing = false
        currentOperation = nil
    }
    
    func aileHesabindanAyril() async throws {
        guard let modelContext = modelContext else { throw AileHataları.contextYok }
        guard let aileHesabi = mevcutAileHesabi else { throw AileHataları.aileHesabiYok }
        guard let currentUserID = cloudKit.currentUserID else { throw AileHataları.kullaniciIDYok }
        
        isProcessing = true
        currentOperation = "family.leaving"
        
        Logger.logFamilyAction("LEAVE_FAMILY_START", details: ["familyID": aileHesabi.id.uuidString])
        
        do {
            // Üyeyi bul ve sil
            if let uye = aileHesabi.uyeler?.first(where: { $0.appleID == currentUserID }) {
                modelContext.delete(uye)
            }
            
            // Eğer admin ayrılıyorsa ve başka üye yoksa, aile hesabını sil
            if aileHesabi.adminID == currentUserID && (aileHesabi.uyeler?.count ?? 0) <= 1 {
                modelContext.delete(aileHesabi)
            }
            
            mevcutAileHesabi = nil
            try modelContext.save()
            
            Logger.logFamilyAction("LEAVE_FAMILY_SUCCESS")
            
        } catch {
            isProcessing = false
            currentOperation = nil
            Logger.logFamilyAction("LEAVE_FAMILY_ERROR", details: ["error": error.localizedDescription], type: .error)
            throw error
        }
        
        isProcessing = false
        currentOperation = nil
    }
    
    // MARK: - Yardımcı Fonksiyonlar
    
    private func kontrolEt() async {
        guard let modelContext = modelContext,
              let currentUserID = cloudKit.currentUserID else { return }
        
        Logger.logFamilyAction("CHECK_FAMILY_STATUS")
        
        // Mevcut aile hesabını kontrol et
        let descriptor = FetchDescriptor<AileHesabi>()
        if let hesaplar = try? modelContext.fetch(descriptor) {
            mevcutAileHesabi = hesaplar.first { hesap in
                hesap.adminID == currentUserID ||
                (hesap.uyeler?.contains { $0.appleID == currentUserID && $0.durum == .aktif } ?? false)
            }
            
            if let aile = mevcutAileHesabi {
                Logger.logFamilyAction("FAMILY_FOUND", details: ["familyID": aile.id.uuidString, "memberCount": aile.uyeler?.count ?? 0])
            }
        }
        
        // Admin davetlerini kontrol et
        if let aileHesabi = mevcutAileHesabi, aileHesabi.adminID == currentUserID {
            let aileID = aileHesabi.id
            let adminDavetDescriptor = FetchDescriptor<AileDavet>(
                predicate: #Predicate { davet in
                    davet.aileHesabiID == aileID
                }
            )
            
            if let davetler = try? modelContext.fetch(adminDavetDescriptor) {
                adminDavetleri = davetler.filter { $0.gecerlilikTarihi > Date() }
                Logger.logFamilyAction("ADMIN_INVITES_LOADED", details: ["count": adminDavetleri.count])
            }
        } else {
            adminDavetleri = []
        }
        
        // Normal kullanıcı davetleri
        let davetDescriptor = FetchDescriptor<AileDavet>(
            predicate: #Predicate { davet in
                davet.davetEdilenID == currentUserID &&
                davet.durumRawValue == "beklemede"
            }
        )
        
        if let davetler = try? modelContext.fetch(davetDescriptor) {
            bekleyenDavetler = davetler.filter { $0.gecerlilikTarihi > Date() }
            Logger.logFamilyAction("USER_INVITES_LOADED", details: ["count": bekleyenDavetler.count])
        }
    }
    
    private func otomatikDavetReddi(kullaniciID: String) async {
        guard let modelContext = modelContext else { return }
        
        let bekleyenDavetler = bekleyenDavetler.filter {
            $0.davetEdilenID == kullaniciID &&
            $0.durum == .beklemede
        }
        
        Logger.logFamilyAction("AUTO_DECLINE_INVITES", details: ["count": bekleyenDavetler.count])
        
        for davet in bekleyenDavetler {
            davet.durum = .otoRed
        }
        
        try? modelContext.save()
    }
    
    private func clearUserData() async throws {
        guard let modelContext = modelContext else { return }
        
        Logger.logFamilyAction("CLEAR_USER_DATA_START")
        
        // Tüm kullanıcı verilerini sil
        try modelContext.delete(model: Islem.self)
        try modelContext.delete(model: Butce.self)
        try modelContext.delete(model: Hesap.self)
        try modelContext.delete(model: Bildirim.self)
        try modelContext.delete(model: TransactionMemory.self)
        
        // Sadece kullanıcı oluşturduğu kategorileri sil
        let userCreatedCategoriesPredicate = #Predicate<Kategori> { $0.localizationKey == nil }
        try modelContext.delete(model: Kategori.self, where: userCreatedCategoriesPredicate)
        
        try modelContext.save()
        
        Logger.logFamilyAction("CLEAR_USER_DATA_SUCCESS")
    }
    
    private func mergeDataToFamily(aileHesabi: AileHesabi) async throws {
        // Mevcut verileri aileye dahil etme mantığı
        // Bu özellik phase 2'de implemente edilebilir
        Logger.logFamilyAction("MERGE_DATA_TO_FAMILY", details: ["familyID": aileHesabi.id.uuidString])
    }
}

// MARK: - Veri Seçeneği
enum VeriSecenegi {
    case temizBaslangic
    case verileriDahilEt
}

// MARK: - Hatalar
enum AileHataları: LocalizedError {
    case contextYok
    case kullaniciIDYok
    case aileHesabiYok
    case zatenAileHesabiVar
    case yetkiYok
    case maksimumUyeSayisi
    case gecersizDavetKodu
    case davetSuresiDolmus
    case zaatenDavetEdilmis
    case zaatenUye
    case davetGecersiz
    case iCloudGerekli
    
    var errorDescription: String? {
        switch self {
        case .contextYok:
            return NSLocalizedString("family.error.no_context", comment: "")
        case .kullaniciIDYok:
            return NSLocalizedString("family.error.no_user_id", comment: "")
        case .aileHesabiYok:
            return NSLocalizedString("family.error.no_family", comment: "")
        case .zatenAileHesabiVar:
            return NSLocalizedString("family.error.already_has_family", comment: "")
        case .yetkiYok:
            return NSLocalizedString("family.error.no_permission", comment: "")
        case .maksimumUyeSayisi:
            return NSLocalizedString("family.error.max_members", comment: "")
        case .gecersizDavetKodu:
            return NSLocalizedString("family.error.invalid_code", comment: "")
        case .davetSuresiDolmus:
            return NSLocalizedString("family.error.code_expired", comment: "")
        case .zaatenDavetEdilmis:
            return NSLocalizedString("family.error.already_invited", comment: "")
        case .zaatenUye:
            return NSLocalizedString("family.error.already_member", comment: "")
        case .davetGecersiz:
            return NSLocalizedString("family.error.invite_invalid", comment: "")
        case .iCloudGerekli:
            return NSLocalizedString("family.error.icloud_required", comment: "")
        }
    }
}
