import SwiftUI
import SwiftData
import RevenueCat // RevenueCat'i import ediyoruz

@main
struct WalleoApp: App {
    // Abonelik durumunu uygulama genelinde yönetecek olan nesne
    @StateObject private var entitlementManager = EntitlementManager()
    
    @StateObject private var appSettings = AppSettings()
    let modelContainer: ModelContainer
    @State private var viewID = UUID()

    init() {
        // --- RevenueCat SDK'sını BAŞLATMA ---
        // DİKKAT: "REVENUECAT_API_KEY" yazan yere kendi RevenueCat Public API Key'inizi yapıştırın.
        Purchases.configure(withAPIKey: "appl_DgbseCsjdacHFLvdfRHlhFqrXMI")
        
        // Geliştirme aşamasında logları görmek için
        Purchases.logLevel = .debug
        
        // --- ModelContainer oluşturma kodunuz aynı kalıyor ---
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
                for: Hesap.self, Islem.self, Kategori.self, Butce.self, Bildirim.self, TransactionMemory.self, AppMetadata.self,
                configurations: config
            )
        } catch {
            Logger.log("KRİTİK HATA: ModelContainer oluşturulamadı. Hata: \(error.localizedDescription)", log: Logger.data, type: .fault)
            fatalError("ModelContainer oluşturulamadı: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            // Onboarding tamamlanıp tamamlanmadığını kontrol et
            if appSettings.hasCompletedOnboarding {
                ContentView()
                    .environmentObject(appSettings)
                    // Abonelik yöneticisini tüm alt görünümlerin erişebilmesi için ortama ekliyoruz
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
            } else {
                OnboardingView()
                    .environmentObject(appSettings)
                    // Abonelik yöneticisini Onboarding ekranına da gönderiyoruz
                    .environmentObject(entitlementManager)
            }
        }
        .modelContainer(modelContainer)
    }

    

    private func deleteAllData() {
        Logger.log("Tüm verileri silme işlemi başlatıldı.", log: Logger.service, type: .info)
        Task {
            await MainActor.run {
                let context = modelContainer.mainContext
                do {
                    // Tüm modelleri tek tek ve toplu olarak sil.
                    try context.delete(model: Islem.self)
                    try context.delete(model: Butce.self)
                    
                    // --- GÜNCELLEME BURADA ---
                    // Sadece kullanıcının oluşturduğu kategorileri (çeviri anahtarı olmayanları) sil.
                    let userCreatedCategoriesPredicate = #Predicate<Kategori> { $0.localizationKey == nil }
                    try context.delete(model: Kategori.self, where: userCreatedCategoriesPredicate)
                    
                    try context.delete(model: Hesap.self)
                    try context.delete(model: Bildirim.self)
                    try context.delete(model: TransactionMemory.self)
                    try context.delete(model: AppMetadata.self)
                    
                    // Değişiklikleri kaydet.
                    try context.save()
                    
                    Logger.log("Tüm kullanıcı verileri başarıyla silindi. Varsayılan kategoriler korundu. Arayüz yeniden başlatılıyor.", log: Logger.service, type: .info)
                    
                    // Arayüzü sıfırdan başlatmak için viewID'yi değiştir.
                    viewID = UUID()
                    
                } catch {
                    Logger.log("Tüm veriler silinirken KRİTİK bir hata oluştu: \(error.localizedDescription)", log: Logger.data, type: .fault)
                }
            }
        }
    }
}
