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
            // CloudKit senkronizasyonunun tamamlanması için DAHA UZUN bekle
            Logger.log("CloudKit senkronizasyonu bekleniyor...", log: Logger.data)
            try await Task.sleep(nanoseconds: 5_000_000_000) // 5 saniye bekle
            
            // Sistem kategorilerini tanımla
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
            
            // ÖNCE: Tüm işlemleri ve mevcut kategori bağlantılarını kaydet
            let allTransactionsDescriptor = FetchDescriptor<Islem>()
            let allTransactions = try context.fetch(allTransactionsDescriptor)
            
            // İşlemlerin orijinal kategori ID'lerini sakla
            var transactionCategoryMap: [UUID: UUID] = [:]
            for transaction in allTransactions {
                if let categoryID = transaction.kategori?.id {
                    transactionCategoryMap[transaction.id] = categoryID
                    Logger.log("İşlem '\(transaction.isim)' kategori ID: \(categoryID)", log: Logger.data)
                }
            }
            
            // Tüm kategorileri çek
            let categoryDescriptor = FetchDescriptor<Kategori>()
            let existingCategories = try context.fetch(categoryDescriptor)
            
            Logger.log("Mevcut kategori sayısı: \(existingCategories.count)", log: Logger.data)
            
            // Kategori ID eşleştirme tablosu (eski ID -> yeni ID)
            var categoryIDMapping: [UUID: UUID] = [:]
            
            // Her sistem kategorisi için kontrol yap
            for systemCat in systemCategories {
                let correctID = systemCat.id
                let locKey = systemCat.localizationKey
                
                // Bu kategorinin tüm varyasyonlarını bul
                let variants = existingCategories.filter { cat in
                    cat.localizationKey == locKey || cat.id == correctID
                }
                
                if variants.isEmpty {
                    // Kategori yok, ekle
                    let newCategory = Kategori(
                        id: correctID,
                        isim: systemCat.isim,
                        ikonAdi: systemCat.ikonAdi,
                        tur: systemCat.tur,
                        renkHex: systemCat.renkHex,
                        localizationKey: locKey
                    )
                    context.insert(newCategory)
                    Logger.log("Eksik kategori eklendi: \(systemCat.isim)", log: Logger.data)
                    
                } else if variants.count == 1 {
                    // Tek kategori var
                    let existingCat = variants[0]
                    
                    if existingCat.id != correctID {
                        // ID yanlış, düzelt
                        Logger.log("Kategori ID düzeltiliyor: \(existingCat.isim)", log: Logger.data)
                        
                        // Eski ID'yi kaydet
                        categoryIDMapping[existingCat.id] = correctID
                        
                        // İşlemleri geçici olarak ayır
                        let transactions = existingCat.islemler ?? []
                        let budgets = existingCat.butceler ?? []
                        
                        // Eski kategoriyi sil
                        context.delete(existingCat)
                        
                        // Yeni kategori oluştur
                        let newCategory = Kategori(
                            id: correctID,
                            isim: systemCat.isim,
                            ikonAdi: existingCat.ikonAdi, // Özelleştirmeleri koru
                            tur: systemCat.tur,
                            renkHex: existingCat.renkHex, // Özelleştirmeleri koru
                            localizationKey: locKey
                        )
                        context.insert(newCategory)
                        
                        // İlişkileri geri bağla
                        for transaction in transactions {
                            transaction.kategori = newCategory
                        }
                        newCategory.butceler = budgets
                    } else {
                        // ID doğru, sadece localizationKey kontrolü
                        if existingCat.localizationKey != locKey {
                            existingCat.localizationKey = locKey
                        }
                    }
                    
                } else {
                    // Birden fazla varyasyon var (duplike)
                    Logger.log("\(variants.count) duplike bulundu: \(systemCat.isim)", log: Logger.data)
                    
                    // Doğru ID'li olanı bul veya ilkini seç
                    let keeper = variants.first { $0.id == correctID } ?? variants[0]
                    
                    // Diğerlerini sil
                    for variant in variants where variant !== keeper {
                        // İşlemleri ana kategoriye aktar
                        let transactions = variant.islemler ?? []
                        let budgets = variant.butceler ?? []
                        
                        for transaction in transactions {
                            transaction.kategori = keeper
                        }
                        keeper.butceler = (keeper.butceler ?? []) + budgets
                        
                        // Eski ID'yi mapping'e ekle
                        if variant.id != correctID {
                            categoryIDMapping[variant.id] = keeper.id
                        }
                        
                        context.delete(variant)
                        Logger.log("Duplike kategori silindi: \(variant.isim)", log: Logger.data)
                    }
                    
                    // Keeper'ın ID'si yanlışsa düzelt
                    if keeper.id != correctID {
                        categoryIDMapping[keeper.id] = correctID
                        
                        let transactions = keeper.islemler ?? []
                        let budgets = keeper.butceler ?? []
                        
                        context.delete(keeper)
                        
                        let newCategory = Kategori(
                            id: correctID,
                            isim: systemCat.isim,
                            ikonAdi: keeper.ikonAdi,
                            tur: systemCat.tur,
                            renkHex: keeper.renkHex,
                            localizationKey: locKey
                        )
                        context.insert(newCategory)
                        
                        for transaction in transactions {
                            transaction.kategori = newCategory
                        }
                        newCategory.butceler = budgets
                    }
                }
            }
            
            // İşlemleri düzelt - orijinal kategori ID'lerine göre
            Logger.log("İşlemler düzeltiliyor...", log: Logger.data)
            
            for transaction in allTransactions {
                // Bu işlemin orijinal kategori ID'si var mı?
                if let originalCategoryID = transactionCategoryMap[transaction.id] {
                    // Bu ID için yeni bir ID var mı?
                    let targetID = categoryIDMapping[originalCategoryID] ?? originalCategoryID
                    
                    // Hedef kategoriyi bul
                    let targetCategoryDescriptor = FetchDescriptor<Kategori>(
                        predicate: #Predicate { $0.id == targetID }
                    )
                    
                    if let targetCategory = try context.fetch(targetCategoryDescriptor).first {
                        if transaction.kategori?.id != targetCategory.id {
                            transaction.kategori = targetCategory
                            Logger.log("İşlem '\(transaction.isim)' kategorisi düzeltildi: \(targetCategory.isim)", log: Logger.data)
                        }
                    } else {
                        Logger.log("UYARI: İşlem '\(transaction.isim)' için kategori bulunamadı (ID: \(targetID))", log: Logger.data, type: .error)
                    }
                } else if transaction.kategori == nil {
                    // Kategorisiz işlem - "Diğer"e ata
                    let otherID = SystemCategoryIDs.other
                    let otherDescriptor = FetchDescriptor<Kategori>(
                        predicate: #Predicate { $0.id == otherID }
                    )
                    
                    if let otherCategory = try context.fetch(otherDescriptor).first {
                        transaction.kategori = otherCategory
                        Logger.log("Kategorisiz işlem '\(transaction.isim)' 'Diğer' kategorisine atandı", log: Logger.data)
                    }
                }
            }
            
            // Metadata güncelle
            let metadataDescriptor = FetchDescriptor<AppMetadata>()
            if let metadata = try context.fetch(metadataDescriptor).first {
                metadata.defaultCategoriesAdded = true
            } else {
                let newMetadata = AppMetadata(defaultCategoriesAdded: true)
                context.insert(newMetadata)
            }
            
            // Kaydet
            try context.save()
            Logger.log("Kategori kontrolü tamamlandı", log: Logger.data)
            
            // UI'ı güncelle
            NotificationCenter.default.post(name: .categoriesDidChange, object: nil)
            NotificationCenter.default.post(name: .transactionsDidChange, object: nil)
            
        } catch {
            Logger.log("Sistem kategorileri kontrol hatası: \(error)", log: Logger.data, type: .error)
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
