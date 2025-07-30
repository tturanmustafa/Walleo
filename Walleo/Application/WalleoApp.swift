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
    
    // WalleoApp.swift içindeki checkAndUpdateSystemCategories fonksiyonu
    // WalleoApp.swift içindeki checkAndUpdateSystemCategories fonksiyonu
    @MainActor
    private func checkAndUpdateSystemCategories() async {
        let context = modelContainer.mainContext
        
        do {
            // CloudKit senkronizasyonunun tamamlanması için bekle
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 saniye
            
            // Metadata kontrolü
            let metadataDescriptor = FetchDescriptor<AppMetadata>()
            let existingMetadata = try context.fetch(metadataDescriptor).first
            
            // Mevcut kategorileri kontrol et
            let categoryDescriptor = FetchDescriptor<Kategori>()
            let existingCategories = try context.fetch(categoryDescriptor)
            
            Logger.log("App başlatıldı - Mevcut kategori sayısı: \(existingCategories.count)", log: Logger.data)
            
            // Sistem kategorilerini tanımla
            let systemCategories: [(isim: String, ikonAdi: String, tur: IslemTuru, renkHex: String, localizationKey: String)] = [
                ("Maaş", "dollarsign.circle.fill", .gelir, "#34C759", "category.salary"),
                ("Ek Gelir", "chart.pie.fill", .gelir, "#007AFF", "category.extra_income"),
                ("Yatırım", "chart.line.uptrend.xyaxis", .gelir, "#AF52DE", "category.investment"),
                ("Market", "cart.fill", .gider, "#FF9500", "category.groceries"),
                ("Restoran", "fork.knife", .gider, "#FF3B30", "category.restaurant"),
                ("Ulaşım", "car.fill", .gider, "#5E5CE6", "category.transport"),
                ("Faturalar", "bolt.fill", .gider, "#FFCC00", "category.bills"),
                ("Eğlence", "film.fill", .gider, "#32ADE6", "category.entertainment"),
                ("Sağlık", "pills.fill", .gider, "#64D2FF", "category.health"),
                ("Giyim", "tshirt.fill", .gider, "#FF2D55", "category.clothing"),
                ("Ev", "house.fill", .gider, "#A2845E", "category.home"),
                ("Hediye", "gift.fill", .gider, "#BF5AF2", "category.gift"),
                ("Kredi Ödemesi", "creditcard.and.123", .gider, "#8E8E93", "category.loan_payment"),
                ("Diğer", "ellipsis.circle.fill", .gider, "#30B0C7", "category.other")
            ]
            
            // Daha güvenli kategori kontrolü
            var kategorilerEklendi = false
            
            for systemCat in systemCategories {
                // Önce localizationKey ile kontrol et
                let existsWithKey = existingCategories.contains { cat in
                    cat.localizationKey == systemCat.localizationKey
                }
                
                // Sonra isim + tür kombinasyonu ile kontrol et
                let existsWithNameAndType = existingCategories.contains { cat in
                    cat.isim == systemCat.isim && cat.tur == systemCat.tur
                }
                
                if existsWithKey {
                    Logger.log("Sistem kategorisi zaten var (key ile): \(systemCat.localizationKey)", log: Logger.data)
                } else if existsWithNameAndType {
                    // İsim ve tür aynı ama localizationKey yok - güncelle
                    if let existingCat = existingCategories.first(where: {
                        $0.isim == systemCat.isim && $0.tur == systemCat.tur && $0.localizationKey == nil
                    }) {
                        existingCat.localizationKey = systemCat.localizationKey
                        kategorilerEklendi = true
                        Logger.log("Mevcut kategoriye localizationKey eklendi: \(systemCat.isim)", log: Logger.data)
                    }
                } else {
                    // Kategori hiç yok, ekle
                    let newCategory = Kategori(
                        isim: systemCat.isim,
                        ikonAdi: systemCat.ikonAdi,
                        tur: systemCat.tur,
                        renkHex: systemCat.renkHex,
                        localizationKey: systemCat.localizationKey
                    )
                    context.insert(newCategory)
                    kategorilerEklendi = true
                    Logger.log("Yeni sistem kategorisi eklendi: \(systemCat.isim)", log: Logger.data)
                }
            }
            
            // Duplike kategorileri temizle
            await cleanupDuplicateCategories(in: context)
            
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
            
        } catch {
            Logger.log("Sistem kategorileri kontrol hatası: \(error)", log: Logger.data, type: .error)
        }
    }

    // Yardımcı fonksiyon - duplike kategorileri temizle
    @MainActor
    private func cleanupDuplicateCategories(in context: ModelContext) async {
        do {
            let categoryDescriptor = FetchDescriptor<Kategori>()
            let allCategories = try context.fetch(categoryDescriptor)
            
            var seenCategories: [String: Kategori] = [:]
            var duplicatesToDelete: [Kategori] = []
            
            for category in allCategories {
                // Sistem kategorileri için localizationKey'i kontrol et
                if let locKey = category.localizationKey, !locKey.isEmpty {
                    if let existing = seenCategories[locKey] {
                        // Hangisi daha eski? Eski olanı sil
                        if existing.olusturmaTarihi < category.olusturmaTarihi {
                            duplicatesToDelete.append(existing)
                            seenCategories[locKey] = category
                        } else {
                            duplicatesToDelete.append(category)
                        }
                        Logger.log("Duplike sistem kategorisi bulundu: \(locKey)", log: Logger.data)
                    } else {
                        seenCategories[locKey] = category
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
