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
    
    private init() {}
    
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
        
        isProcessing = true
        currentOperation = "family.creating"
        
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
            
        } catch {
            isProcessing = false
            currentOperation = nil
            throw error
        }
        
        isProcessing = false
        currentOperation = nil
    }
    
    func uyeEkle(email: String, gorunumIsmi: String) async throws {
        guard let aileHesabi = mevcutAileHesabi else { throw AileHataları.aileHesabiYok }
        guard let currentUserID = cloudKit.currentUserID else { throw AileHataları.kullaniciIDYok }
        guard let modelContext = modelContext else { throw AileHataları.contextYok }
        
        Logger.log("Üye ekleme başlatıldı - Email: \(email), Görünüm İsmi: \(gorunumIsmi)", log: Logger.service)
        
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
            (davet.davetEdilenID == "pending_\(email)" ||
             davet.davetEdilenID.contains(email)) &&
            davet.durum == .beklemede
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
                Logger.log("Kullanıcı bulundu - ID: \(userID), İsim: \(displayName)", log: Logger.service)
            } catch {
                // User discovery başarısız olursa, geçici bir ID oluştur
                Logger.log("User discovery failed: \(error), creating placeholder invite", log: Logger.service, type: .error)
                userID = "pending_\(email)"
                displayName = gorunumIsmi
            }
            
            // Davet oluştur
            let davet = AileDavet(
                aileHesabiID: aileHesabi.id,
                aileHesabiIsmi: aileHesabi.isim,
                davetEdenID: currentUserID,
                davetEdenIsim: "Admin",
                davetEdilenID: userID
            )
            
            modelContext.insert(davet)
            try modelContext.save()
            
            Logger.log("Member invited successfully - Davet ID: \(davet.id)", log: Logger.service)
            
            // Davet listesini güncelle
            await kontrolEt()
            
        } catch {
            isProcessing = false
            currentOperation = nil
            Logger.log("Üye ekleme hatası: \(error)", log: Logger.service, type: .error)
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
            
        } catch {
            isProcessing = false
            currentOperation = nil
            throw error
        }
        
        isProcessing = false
        currentOperation = nil
    }
    
    func daveteYanitVer(davet: AileDavet, kabul: Bool) async throws {
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
                    // Yeni üye ekle
                    let yeniUye = AileUyesi(
                        appleID: currentUserID,
                        gorunumIsmi: davet.davetEdilenID.hasPrefix("pending_") ?
                                     String(davet.davetEdilenID.dropFirst(8)) :
                                     "Üye",
                        durum: .aktif
                    )
                    yeniUye.aileHesabi = aileHesabi
                    modelContext.insert(yeniUye)
                    
                    mevcutAileHesabi = aileHesabi
                } else {
                    throw AileHataları.aileHesabiYok
                }
            }
            
            // Daveti güncelle
            davet.durum = kabul ? .kabul : .red
            try modelContext.save()
            
            // Listeleri güncelle
            await kontrolEt()
            
        } catch {
            isProcessing = false
            currentOperation = nil
            throw error
        }
        
        isProcessing = false
        currentOperation = nil
    }
    
    // MARK: - Davet Kodu İşlemleri
    
    func davetKoduOlustur(kod: String) async throws {
        guard let aileHesabi = mevcutAileHesabi else { throw AileHataları.aileHesabiYok }
        guard let currentUserID = cloudKit.currentUserID else { throw AileHataları.kullaniciIDYok }
        guard let modelContext = modelContext else { throw AileHataları.contextYok }
        
        // Admin kontrolü
        guard aileHesabi.adminID == currentUserID else {
            throw AileHataları.yetkiYok
        }
        
        // Davet oluştur (davet kodu ile)
        let davet = AileDavet(
            aileHesabiID: aileHesabi.id,
            aileHesabiIsmi: aileHesabi.isim,
            davetEdenID: currentUserID,
            davetEdenIsim: "Admin",
            davetEdilenID: "DAVET_KODU_\(kod)" // Özel prefix ile işaretle
        )
        
        modelContext.insert(davet)
        try modelContext.save()
    }
    
    func davetKoduylaKatil(kod: String) async throws {
        guard let modelContext = modelContext else { throw AileHataları.contextYok }
        guard let currentUserID = cloudKit.currentUserID else { throw AileHataları.kullaniciIDYok }
        
        // Davet kodunu bul
        let davetKoduID = "DAVET_KODU_\(kod)"
        let descriptor = FetchDescriptor<AileDavet>(
            predicate: #Predicate { davet in
                davet.davetEdilenID == davetKoduID &&
                davet.durumRawValue == "beklemede"
            }
        )
        
        guard let davet = try modelContext.fetch(descriptor).first else {
            throw AileHataları.gecersizDavetKodu
        }
        
        // Geçerlilik kontrolü
        guard davet.gecerlilikTarihi > Date() else {
            throw AileHataları.davetSuresiDolmus
        }
        
        // Daveti kabul et
        davet.davetEdilenID = currentUserID
        try await daveteYanitVer(davet: davet, kabul: true)
    }
    
    private func kontrolEt() async {
        guard let modelContext = modelContext,
              let currentUserID = cloudKit.currentUserID else { return }
        
        Logger.log("Aile hesabı kontrolü başlatıldı - User ID: \(currentUserID)", log: Logger.service)
        
        // Mevcut aile hesabını kontrol et
        let descriptor = FetchDescriptor<AileHesabi>()
        if let hesaplar = try? modelContext.fetch(descriptor) {
            mevcutAileHesabi = hesaplar.first { hesap in
                hesap.adminID == currentUserID ||
                (hesap.uyeler?.contains { $0.appleID == currentUserID && $0.durum == .aktif } ?? false)
            }
            
            if let aile = mevcutAileHesabi {
                Logger.log("Aile hesabı bulundu: \(aile.isim) - Üye sayısı: \(aile.uyeler?.count ?? 0)", log: Logger.service)
            }
        }
        
        // Bekleyen davetleri kontrol et
        let currentUserIDForPredicate = currentUserID
        
        // İki tür davet kontrol et:
        // 1. Bu kullanıcıya gönderilen davetler
        // 2. Bu kullanıcının admin olduğu ailenin pending davetleri
        
        if let aileHesabi = mevcutAileHesabi, aileHesabi.adminID == currentUserID {
            // Admin ise, kendi ailesinin tüm davetlerini göster
            let aileID = aileHesabi.id
            let adminDavetDescriptor = FetchDescriptor<AileDavet>(
                predicate: #Predicate { davet in
                    davet.aileHesabiID == aileID &&
                    davet.durumRawValue == "beklemede"
                }
            )
            
            if let davetler = try? modelContext.fetch(adminDavetDescriptor) {
                adminDavetleri = davetler.filter { $0.gecerlilikTarihi > Date() }
                Logger.log("Admin için bekleyen davet sayısı: \(adminDavetleri.count)", log: Logger.service)
            }
        } else {
            adminDavetleri = []
        }
        
        // Normal kullanıcı davetleri
        let davetDescriptor = FetchDescriptor<AileDavet>(
            predicate: #Predicate { davet in
                davet.davetEdilenID == currentUserIDForPredicate &&
                davet.durumRawValue == "beklemede"
            }
        )
        
        if let davetler = try? modelContext.fetch(davetDescriptor) {
            bekleyenDavetler = davetler.filter { $0.gecerlilikTarihi > Date() }
            Logger.log("Kullanıcı için bekleyen davet sayısı: \(bekleyenDavetler.count)", log: Logger.service)
        }
    }
}

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
        }
    }
}

