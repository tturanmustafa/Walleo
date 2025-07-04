import SwiftUI
import SwiftData

@main
struct WalleoApp: App {
    @StateObject private var appSettings = AppSettings()
    let modelContainer: ModelContainer
    @State private var viewID = UUID()

    init() {
        // Kullanıcının iCloud tercihini AppSettings'ten oku.
        let isCloudKitEnabled = AppSettings().isCloudKitEnabled
        Logger.log("Uygulama başlatılıyor. iCloud Yedekleme durumu: \(isCloudKitEnabled ? "AÇIK" : "KAPALI")", log: Logger.service, type: .default)

        do {
            // Tercihe göre ModelConfiguration oluştur.
            let config: ModelConfiguration
            
            if isCloudKitEnabled {
                // Eğer AÇIK ise, CloudKit konfigürasyonu ile oluştur.
                config = ModelConfiguration(
                    "WalleoDB",
                    cloudKitDatabase: .private("iCloud.com.mustafamt.walleo")
                )
            } else {
                // Eğer KAPALI ise, SADECE LOKAL konfigürasyon ile oluştur.
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
        if appSettings.hasCompletedOnboarding {
            ContentView()
                .environmentObject(appSettings)
                .preferredColorScheme(appSettings.colorScheme)
                .environment(\.locale, Locale(identifier: appSettings.languageCode))
                .id(viewID)
                .task {
                    // .task içeriği aynı
                }
                .onReceive(NotificationCenter.default.publisher(for: .appShouldRestart)) { _ in
                    // Hem dil hem de iCloud ayarı değiştiğinde bu bildirim tetiklenir.
                    // viewID değişir ve tüm arayüz yeniden çizilir.
                    // WalleoApp yeniden başlatıldığı için, yeni init metodu
                    // güncel iCloud ayarına göre doğru ModelContainer'ı oluşturur.
                    viewID = UUID()
                }
                .onReceive(NotificationCenter.default.publisher(for: .appShouldDeleteAllData)) { _ in
                    deleteAllData()
                }
        } else {
            OnboardingView()
                .environmentObject(appSettings)
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
