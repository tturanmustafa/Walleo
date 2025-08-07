import SwiftUI
import SwiftData
import RevenueCat
import CloudKit
import BackgroundTasks
import UserNotifications // YENİ: Ekleyin

// YENİ: AppDelegate sınıfı
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        completionHandler()
    }
}

@main
struct WalleoApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var entitlementManager = EntitlementManager()
    @StateObject private var appSettings = AppSettings()
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    let modelContainer: ModelContainer
    @State private var viewID = UUID()
    private let budgetRenewalTaskID = "com.walleo.bgtask.renewBudgets"

    init() {
        Purchases.configure(withAPIKey: "appl_DgbseCsjdacHFLvdfRHlhFqrXMI")
        Purchases.logLevel = .debug
        
        let isCloudKitEnabled = AppSettings().isCloudKitEnabled
        Logger.log("Uygulama başlatılıyor. iCloud Yedekleme durumu: \(isCloudKitEnabled ? "AÇIK" : "KAPALI")", log: Logger.service, type: .default)

        do {
            let config: ModelConfiguration
            if isCloudKitEnabled {
                config = ModelConfiguration("WalleoDB", cloudKitDatabase: .private("iCloud.com.mustafamt.walleo"))
            } else {
                config = ModelConfiguration("WalleoDB")
            }
            
            modelContainer = try ModelContainer(
                for: Hesap.self, Islem.self, Kategori.self, Butce.self,
                     Bildirim.self, TransactionMemory.self, AppMetadata.self, Transfer.self,
                configurations: config
            )
        } catch {
            fatalError("ModelContainer oluşturulamadı: \(error)")
        }
        registerBackgroundTask()
        
        // NotificationManager başlatmayı buradan kaldırın
    }

    var body: some Scene {
        WindowGroup {
            if appSettings.hasCompletedOnboarding {
                ContentView()
                    .environmentObject(appSettings)
                    .environmentObject(entitlementManager)
                    .preferredColorScheme(appSettings.colorScheme)
                    .environment(\.locale, Locale(identifier: appSettings.languageCode))
                    .id(viewID)
                    .onReceive(NotificationCenter.default.publisher(for: .appShouldRestart)) { _ in
                        viewID = UUID()
                    }
                    .onReceive(NotificationCenter.default.publisher(for: .appShouldDeleteAllData)) { _ in
                        deleteAllData()
                    }
                    .onChange(of: scenePhase) { _, newPhase in
                        if newPhase == .active {
                            NotificationManager.shared.updateBadgeCount()
                        }
                    }
                    // YENİ: NotificationManager'ı burada başlatın
                    .task {
                        // NotificationManager'ı kur
                        await setupNotificationManager()
                        await checkAndUpdateSystemCategories()
                    }
            } else {
                OnboardingView()
                    .environmentObject(appSettings)
                    .environmentObject(entitlementManager)
                    .modelContainer(modelContainer)
                    // YENİ: Onboarding için de ekleyin
                    .task {
                        // Önce NotificationManager'ı kur
                        await setupNotificationManager()
                        
                        // Sonra sistem kategorilerini kontrol et
                        // (checkAndUpdateSystemCategories içinde zaten delay var)
                        await checkAndUpdateSystemCategories()
                    }
            }
        }
        .modelContainer(modelContainer)
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .background {
                scheduleBudgetRenewalTask()
            }
        }
    }
    
    // WalleoApp.swift içindeki checkAndUpdateSystemCategories fonksiyonu - KOMPLE DEĞİŞTİR
    @MainActor
    private func checkAndUpdateSystemCategories() async {
        let context = modelContainer.mainContext
        
        do {
            // CloudKit senkronizasyonunun tamamlanması için bekle
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 saniye bekle
            
            // Metadata kontrolü
            let metadataDescriptor = FetchDescriptor<AppMetadata>()
            let existingMetadata = try context.fetch(metadataDescriptor).first
            
            // Mevcut kategorileri kontrol et
            let categoryDescriptor = FetchDescriptor<Kategori>()
            let existingCategories = try context.fetch(categoryDescriptor)
            
            Logger.log("App başlatıldı - Mevcut kategori sayısı: \(existingCategories.count)", log: Logger.data)
            
            // Sistem kategorilerini tanımla - SABİT UUID'lerle
            let systemCategories: [(id: UUID, isim: String, ikonAdi: String, tur: IslemTuru, renkHex: String, localizationKey: String)] = [
                (SystemCategoryIDs.salary, "Maaş", "dollarsign.circle.fill", .gelir, "#34C759", "category.salary"),
                (SystemCategoryIDs.extraIncome, "Ek Gelir", "chart.pie.fill", .gelir, "#007AFF", "category.extra_income"),
                (SystemCategoryIDs.investment, "Yatırım", "chart.line.uptrend.xyaxis", .gelir, "#AF52DE", "category.investment"),
                (SystemCategoryIDs.groceries, "Market", "cart.fill", .gider, "#FF9500", "category.groceries"),
                (SystemCategoryIDs.restaurant, "Restoran", "fork.knife", .gider, "#FF3B30", "category.restaurant"),
                (SystemCategoryIDs.transport, "Ulaşım", "car.fill", .gider, "#5E5CE6", "category.transport"),
                (SystemCategoryIDs.bills, "Faturalar", "bolt.fill", .gider, "#FFCC00", "category.bills"),
                (SystemCategoryIDs.entertainment, "Eğlence", "film.fill", .gider, "#32ADE6", "category.entertainment"),
                (SystemCategoryIDs.health, "Sağlık", "pills.fill", .gider, "#64D2FF", "category.health"),
                (SystemCategoryIDs.clothing, "Giyim", "tshirt.fill", .gider, "#FF2D55", "category.clothing"),
                (SystemCategoryIDs.home, "Ev", "house.fill", .gider, "#A2845E", "category.home"),
                (SystemCategoryIDs.gift, "Hediye", "gift.fill", .gider, "#BF5AF2", "category.gift"),
                (SystemCategoryIDs.loanPayment, "Kredi Ödemesi", "creditcard.and.123", .gider, "#8E8E93", "category.loan_payment"),
                (SystemCategoryIDs.other, "Diğer", "ellipsis.circle.fill", .gider, "#30B0C7", "category.other")
            ]
            
            var kategorilerEklendi = false
            
            // ÖNEMLİ: Önce eski sistem kategorilerini temizle/migrate et
            for systemCat in systemCategories {
                // Yeni ID'li kategori var mı?
                let existsWithNewID = existingCategories.first { $0.id == systemCat.id }
                
                // Eski sistem kategorisi var mı? (localizationKey ile kontrol)
                let oldSystemCategory = existingCategories.first { cat in
                    cat.id != systemCat.id && // Farklı ID
                    cat.localizationKey == systemCat.localizationKey // Aynı localizationKey
                }
                
                if let oldCategory = oldSystemCategory {
                    // ESKİ SİSTEM KATEGORİSİ VAR - MIGRATE ET
                    Logger.log("Eski sistem kategorisi bulundu, migrate ediliyor: \(systemCat.isim)", log: Logger.data)
                    
                    if existsWithNewID != nil {
                        // Hem eski hem yeni var - eskiyi sil
                        let transactions = oldCategory.islemler ?? []
                        for transaction in transactions {
                            transaction.kategori = existsWithNewID
                        }
                        context.delete(oldCategory)
                        Logger.log("Duplike eski kategori silindi: \(systemCat.isim)", log: Logger.data)
                    } else {
                        // Sadece eski var - ID'sini güncelle (yeniden oluşturma yöntemi)
                        let transactions = oldCategory.islemler ?? []
                        let budgets = oldCategory.butceler ?? []
                        let userIcon = oldCategory.ikonAdi
                        let userColor = oldCategory.renkHex
                        
                        // Eski kategoriyi sil
                        context.delete(oldCategory)
                        
                        // Yeni ID'li kategori oluştur
                        let newCategory = Kategori(
                            id: systemCat.id,
                            isim: systemCat.isim,
                            ikonAdi: userIcon, // Kullanıcı özelleştirmelerini koru
                            tur: systemCat.tur,
                            renkHex: userColor, // Kullanıcı özelleştirmelerini koru
                            localizationKey: systemCat.localizationKey
                        )
                        context.insert(newCategory)
                        
                        // İlişkileri aktar
                        for transaction in transactions {
                            transaction.kategori = newCategory
                        }
                        newCategory.butceler = budgets
                        
                        Logger.log("Kategori migrate edildi: \(systemCat.isim)", log: Logger.data)
                    }
                    kategorilerEklendi = true
                    
                } else if existsWithNewID == nil {
                    // Hiç kategori yok - yeni oluştur
                    let newCategory = Kategori(
                        id: systemCat.id,
                        isim: systemCat.isim,
                        ikonAdi: systemCat.ikonAdi,
                        tur: systemCat.tur,
                        renkHex: systemCat.renkHex,
                        localizationKey: systemCat.localizationKey
                    )
                    context.insert(newCategory)
                    kategorilerEklendi = true
                    Logger.log("Yeni sistem kategorisi eklendi: \(systemCat.isim)", log: Logger.data)
                    
                } else if let existingCat = existsWithNewID {
                    // Yeni ID'li kategori zaten var - sadece kritik alanları kontrol et
                    var needsUpdate = false
                    
                    if existingCat.localizationKey != systemCat.localizationKey {
                        existingCat.localizationKey = systemCat.localizationKey
                        needsUpdate = true
                    }
                    
                    if existingCat.isim.isEmpty {
                        existingCat.isim = systemCat.isim
                        needsUpdate = true
                    }
                    
                    if needsUpdate {
                        kategorilerEklendi = true
                        Logger.log("Kategori güncellendi: \(systemCat.isim)", log: Logger.data)
                    }
                }
            }
            
            // Metadata güncelle
            if existingMetadata == nil {
                let newMetadata = AppMetadata(defaultCategoriesAdded: true)
                context.insert(newMetadata)
                kategorilerEklendi = true
            } else if !existingMetadata!.defaultCategoriesAdded {
                existingMetadata!.defaultCategoriesAdded = true
                kategorilerEklendi = true
            }
            
            // Değişiklik varsa kaydet
            if kategorilerEklendi {
                try context.save()
                Logger.log("Sistem kategorileri güncelleme kontrolü tamamlandı", log: Logger.data)
            }
            
            // Kategorisiz işlemleri düzelt
            await fixOrphanedTransactions(in: context)
            
        } catch {
            Logger.log("Sistem kategorileri kontrol hatası: \(error.localizedDescription)", log: Logger.data, type: .error)
        }
    }
    
    // YENİ FONKSİYON - WalleoApp.swift'e EKLE
    @MainActor
    private func fixOrphanedTransactions(in context: ModelContext) async {
        do {
            // Kategorisiz işlemleri bul
            let orphanedTransactionDescriptor = FetchDescriptor<Islem>(
                predicate: #Predicate { islem in
                    islem.kategori == nil
                }
            )
            
            let orphanedTransactions = try context.fetch(orphanedTransactionDescriptor)
            
            if !orphanedTransactions.isEmpty {
                Logger.log("Kategorisiz işlem bulundu: \(orphanedTransactions.count) adet", log: Logger.data)
                
                // "Diğer" kategorisini bul - ÖNEMLİ: UUID'yi önce bir değişkene ata
                let otherCategoryID = SystemCategoryIDs.other
                let otherCategoryDescriptor = FetchDescriptor<Kategori>(
                    predicate: #Predicate { kategori in
                        kategori.id == otherCategoryID
                    }
                )
                
                if let otherCategory = try context.fetch(otherCategoryDescriptor).first {
                    for transaction in orphanedTransactions {
                        transaction.kategori = otherCategory
                        Logger.log("İşlem '\(transaction.isim)' 'Diğer' kategorisine atandı", log: Logger.data)
                    }
                    
                    try context.save()
                    Logger.log("Kategorisiz işlemler düzeltildi", log: Logger.data)
                    
                    // UI'ı güncelle
                    NotificationCenter.default.post(name: .transactionsDidChange, object: nil)
                } else {
                    Logger.log("UYARI: 'Diğer' kategorisi bulunamadı!", log: Logger.data, type: .error)
                }
            }
        } catch {
            Logger.log("Kategorisiz işlemleri düzeltme hatası: \(error)", log: Logger.data, type: .error)
        }
    }    // Yardımcı fonksiyon - duplike kategorileri temizle
    @MainActor
    private func cleanupDuplicateCategories(in context: ModelContext) async {
        do {
            let categoryDescriptor = FetchDescriptor<Kategori>()
            let allCategories = try context.fetch(categoryDescriptor)
            
            var seenSystemCategories: [UUID: Kategori] = [:]
            var duplicatesToDelete: [Kategori] = []
            
            for category in allCategories {
                // Sistem kategorileri için ID kontrolü
                if SystemCategoryIDs.allIDs.contains(category.id) {
                    if let existing = seenSystemCategories[category.id] {
                        // Hangisi daha eski? Yenisini tut, eskiyi sil
                        if existing.olusturmaTarihi < category.olusturmaTarihi {
                            // Eski kategoriyi kullanan işlemleri yeniye aktar
                            let oldTransactions = existing.islemler ?? []
                            for transaction in oldTransactions {
                                transaction.kategori = category
                            }
                            duplicatesToDelete.append(existing)
                            seenSystemCategories[category.id] = category
                        } else {
                            // Yeni kategoriyi kullanan işlemleri eskiye aktar
                            let newTransactions = category.islemler ?? []
                            for transaction in newTransactions {
                                transaction.kategori = existing
                            }
                            duplicatesToDelete.append(category)
                        }
                        Logger.log("Duplike sistem kategorisi bulundu: \(category.isim)", log: Logger.data)
                    } else {
                        seenSystemCategories[category.id] = category
                    }
                }
            }
            
            // Duplikleri sil
            for duplicate in duplicatesToDelete {
                context.delete(duplicate)
                Logger.log("Duplike kategori silindi: \(duplicate.isim)", log: Logger.data)
            }
            
            if !duplicatesToDelete.isEmpty {
                try context.save()
                Logger.log("\(duplicatesToDelete.count) duplike kategori temizlendi", log: Logger.data)
            }
            
        } catch {
            Logger.log("Duplike temizleme hatası: \(error)", log: Logger.data, type: .error)
        }
    }
    
    // YENİ: NotificationManager setup fonksiyonu
    @MainActor
    private func setupNotificationManager() async {
        let context = modelContainer.mainContext
        NotificationManager.shared.configure(
            modelContext: context,
            appSettings: appSettings
        )
        
        // İzin iste ve genel hatırlatıcıları kur
        NotificationManager.shared.requestAuthorization { granted in
            if granted && self.appSettings.masterNotificationsEnabled {
                NotificationManager.shared.scheduleGenericReminders()
            }
        }
    }
    // Diğer fonksiyonlar aynı kalacak...
    private func deleteAllData() {
        Task {
            await MainActor.run {
                let context = modelContainer.mainContext
                do {
                    try context.delete(model: Islem.self)
                    try context.delete(model: Butce.self)
                    let userCreatedCategoriesPredicate = #Predicate<Kategori> { $0.localizationKey == nil }
                    try context.delete(model: Kategori.self, where: userCreatedCategoriesPredicate)
                    try context.delete(model: Hesap.self)
                    try context.delete(model: Bildirim.self)
                    try context.delete(model: TransactionMemory.self)
                    try context.delete(model: AppMetadata.self)
                    try context.save()
                    viewID = UUID()
                } catch {
                    Logger.log("Tüm veriler silinirken hata oluştu: \(error.localizedDescription)", log: Logger.data, type: .fault)
                }
            }
        }
    }

    private func registerBackgroundTask() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: budgetRenewalTaskID, using: nil) { task in
            Logger.log("Arka plan bütçe yenileme görevi BAŞLADI.", log: Logger.service, type: .info)
            
            task.expirationHandler = {
                task.setTaskCompleted(success: false)
                Logger.log("Arka plan görevi zaman aşımına uğradı.", log: Logger.service, type: .error)
            }

            let backgroundContext = ModelContext(self.modelContainer)
            let service = BudgetRenewalService(modelContext: backgroundContext)
            
            Task {
                await service.runDailyChecks()
                
                do {
                    try backgroundContext.save()
                    task.setTaskCompleted(success: true)
                    Logger.log("Arka plan görevi TAMAMLANDI ve değişiklikler kaydedildi.", log: Logger.service)
                } catch {
                    task.setTaskCompleted(success: false)
                    Logger.log("Arka plan context'i kaydedilirken hata: \(error)", log: Logger.service, type: .error)
                }
                
                self.scheduleBudgetRenewalTask()
            }
        }
    }

    private func scheduleBudgetRenewalTask() {
        let request = BGAppRefreshTaskRequest(identifier: budgetRenewalTaskID)
        request.earliestBeginDate = Calendar.current.date(byAdding: .hour, value: 3, to: Date())
        
        do {
            try BGTaskScheduler.shared.submit(request)
            Logger.log("Bütçe yenileme görevi başarıyla zamanlandı.", log: Logger.service)
        } catch {
            Logger.log("Bütçe yenileme görevi zamanlanamadı: \(error)", log: Logger.service, type: .error)
        }
    }
}
