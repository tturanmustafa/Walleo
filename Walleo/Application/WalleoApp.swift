import SwiftUI
import SwiftData
import RevenueCat
import CloudKit
import BackgroundTasks // Arka plan görevleri için bu framework'ü import ediyoruz

@main
struct WalleoApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var entitlementManager = EntitlementManager()
    @StateObject private var appSettings = AppSettings()
    @StateObject private var cloudKitManager = CloudKitManager.shared
    
    let modelContainer: ModelContainer
    @State private var viewID = UUID()
    private let budgetRenewalTaskID = "com.walleo.bgtask.renewBudgets"

    init() {
        // RevenueCat SDK'sını başlat
        Purchases.configure(withAPIKey: "appl_DgbseCsjdacHFLvdfRHlhFqrXMI")
        Purchases.logLevel = .debug
        
        // ModelContainer oluştur
        let isCloudKitEnabled = AppSettings().isCloudKitEnabled
        Logger.log("Uygulama başlatılıyor. iCloud Yedekleme durumu: \(isCloudKitEnabled ? "AÇIK" : "KAPALI")", log: Logger.service, type: .default)

        do {
            let config: ModelConfiguration
            if isCloudKitEnabled {
                config = ModelConfiguration(
                    "WalleoDB",
                    cloudKitDatabase: .private("iCloud.com.mustafamt.walleo")
                )
            } else {
                config = ModelConfiguration("WalleoDB")
            }

            modelContainer = try ModelContainer(
                for: Hesap.self, Islem.self, Kategori.self, Butce.self,
                     Bildirim.self, TransactionMemory.self, AppMetadata.self,
                     AileHesabi.self, AileUyesi.self, AileDavet.self,
                configurations: config
            )
        } catch {
            Logger.log("KRİTİK HATA: ModelContainer oluşturulamadı. Hata: \(error.localizedDescription)", log: Logger.data, type: .fault)
            fatalError("ModelContainer oluşturulamadı: \(error)")
        }
        registerBackgroundTask()
    }

    var body: some Scene {
        WindowGroup {
            if appSettings.hasCompletedOnboarding {
                ContentView()
                    .environmentObject(appSettings)
                    .environmentObject(entitlementManager)
                    .environmentObject(cloudKitManager)
                    .preferredColorScheme(appSettings.colorScheme)
                    .environment(\.locale, Locale(identifier: appSettings.languageCode))
                    .id(viewID)
                    .onReceive(NotificationCenter.default.publisher(for: .appShouldRestart)) { _ in
                        viewID = UUID()
                    }
                    .onReceive(NotificationCenter.default.publisher(for: .appShouldDeleteAllData)) { _ in
                        deleteAllData()
                    }
                    .task {
                        // CloudKit durumunu kontrol et
                        await cloudKitManager.checkAvailability()
                        // CloudKit permissions'ları request et
                        await requestCloudKitPermissions()
                    }
            } else {
                OnboardingView()
                    .environmentObject(appSettings)
                    .environmentObject(entitlementManager)
                    .environmentObject(cloudKitManager)
            }
        }
        .modelContainer(modelContainer)
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .background {
                // Uygulama arka plana atıldığında, bütçe yenileme görevini zamanla
                scheduleBudgetRenewalTask()
            }
        }
    }

    private func deleteAllData() {
        // Aile hesabı kontrolü
        if AileHesabiService.shared.mevcutAileHesabi != nil {
            Logger.log("Aile hesabı aktifken veri silme engellendi", log: Logger.service, type: .default)
            // TODO: Burada kullanıcıya bir alert gösterilebilir
            return
        }
        
        Logger.log("Tüm verileri silme işlemi başlatıldı.", log: Logger.service, type: .info)
        Task {
            await MainActor.run {
                let context = modelContainer.mainContext
                do {
                    // Tüm modelleri sil
                    try context.delete(model: Islem.self)
                    try context.delete(model: Butce.self)
                    
                    // Sadece kullanıcı oluşturduğu kategorileri sil
                    let userCreatedCategoriesPredicate = #Predicate<Kategori> { $0.localizationKey == nil }
                    try context.delete(model: Kategori.self, where: userCreatedCategoriesPredicate)
                    
                    try context.delete(model: Hesap.self)
                    try context.delete(model: Bildirim.self)
                    try context.delete(model: TransactionMemory.self)
                    try context.delete(model: AppMetadata.self)
                    
                    // Aile hesabı modellerini de sil
                    try context.delete(model: AileDavet.self)
                    try context.delete(model: AileUyesi.self)
                    try context.delete(model: AileHesabi.self)
                    
                    try context.save()
                    
                    Logger.log("Tüm kullanıcı verileri başarıyla silindi.", log: Logger.service, type: .info)
                    viewID = UUID()
                    
                } catch {
                    Logger.log("Tüm veriler silinirken hata oluştu: \(error.localizedDescription)", log: Logger.data, type: .fault)
                }
            }
        }
    }
    
    private func requestCloudKitPermissions() async {
        let container = CKContainer(identifier: "iCloud.com.mustafamt.walleo")
        
        do {
            let status = try await container.accountStatus()
            if status == .available {
                // Request permission for user discovery
                let _ = try await container.requestApplicationPermission(.userDiscoverability)
                Logger.log("CloudKit permissions requested successfully", log: Logger.service)
            }
        } catch {
            Logger.log("CloudKit permission request failed: \(error)", log: Logger.service, type: .error)
        }
    }
    private func registerBackgroundTask() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: budgetRenewalTaskID, using: nil) { task in
            Logger.log("Arka plan bütçe yenileme görevi BAŞLADI.", log: Logger.service, type: .info)
            
            task.expirationHandler = {
                task.setTaskCompleted(success: false)
                Logger.log("Arka plan görevi zaman aşımına uğradı.", log: Logger.service, type: .error)
            }

            // --- DÜZELTME: GÜVENLİ VERİTABANI BAĞLANTISI ---
            // Arka plan görevi için ana konteynırdan yeni ve bağımsız bir context oluşturuyoruz.
            let backgroundContext = ModelContext(modelContainer)
            let service = BudgetRenewalService(modelContext: backgroundContext)
            // --- DÜZELTME SONU ---
            
            Task {
                await service.runDailyChecks()
                
                // Değişiklikleri kaydetmeye çalış
                do {
                    try backgroundContext.save()
                    task.setTaskCompleted(success: true)
                    Logger.log("Arka plan görevi TAMAMLANDI ve değişiklikler kaydedildi.", log: Logger.service, type: .info)
                } catch {
                    task.setTaskCompleted(success: false)
                    Logger.log("Arka plan context'i kaydedilirken hata: \(error)", log: Logger.service, type: .error)
                }
                
                self.scheduleBudgetRenewalTask()
            }
        }
    }

    /// Arka plan görevinin bir sonraki sefer için çalışmasını iOS'tan talep eder.
    private func scheduleBudgetRenewalTask() {
        let request = BGAppRefreshTaskRequest(identifier: budgetRenewalTaskID)
        // Görevin en erken ne zaman çalışabileceğini belirtiyoruz (örn: 3 saat sonra)
        request.earliestBeginDate = Calendar.current.date(byAdding: .hour, value: 3, to: Date())
        
        do {
            try BGTaskScheduler.shared.submit(request)
            Logger.log("Bütçe yenileme görevi başarıyla zamanlandı.", log: Logger.service)
        } catch {
            Logger.log("Bütçe yenileme görevi zamanlanamadı: \(error)", log: Logger.service, type: .error)
        }
    }
}
