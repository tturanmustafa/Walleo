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
        }
        .modelContainer(modelContainer)
    }

    
    // --- BU FONKSİYON TAMAMEN YENİLENDİ ---
    @MainActor
    private func addDefaultCategoriesIfNeeded() async {
        let modelContext = modelContainer.mainContext
        
        // 1. Adım: Meta veri nesnesi var mı diye kontrol et.
        let descriptor = FetchDescriptor<AppMetadata>()
        if let metadata = try? modelContext.fetch(descriptor).first {
            // Eğer meta veri varsa ve kategoriler zaten eklenmişse, hiçbir şey yapma.
            if metadata.defaultCategoriesAdded {
                Logger.log("Varsayılan kategoriler zaten mevcut, ekleme adımı atlandı.", log: Logger.service, type: .info)
                return
            }
        }

        // Bu noktaya geldiysek, ya hiç meta veri yoktur (ilk açılış) ya da bir hata sonucu bayrak false kalmıştır.
        // Her ihtimale karşı veritabanında kategori var mı diye son bir kontrol yapmak yine de iyidir.
        let categoryDescriptor = FetchDescriptor<Kategori>()
        let existingCategories = try? modelContext.fetch(categoryDescriptor)
        
        // Eğer veritabanı gerçekten boşsa, kategorileri ekle.
        if existingCategories?.isEmpty ?? true {
            Logger.log("Veritabanı boş. Varsayılan kategoriler ekleniyor...", log: Logger.service, type: .info)

            // Varsayılan kategoriler ekleniyor...
            modelContext.insert(Kategori(isim: "Maaş", ikonAdi: "dollarsign.circle.fill", tur: .gelir, renkHex: "#34C759", localizationKey: "category.salary"))
            modelContext.insert(Kategori(isim: "Ek Gelir", ikonAdi: "chart.pie.fill", tur: .gelir, renkHex: "#007AFF", localizationKey: "category.extra_income"))
            modelContext.insert(Kategori(isim: "Yatırım", ikonAdi: "chart.line.uptrend.xyaxis", tur: .gelir, renkHex: "#AF52DE", localizationKey: "category.investment"))
            modelContext.insert(Kategori(isim: "Market", ikonAdi: "cart.fill", tur: .gider, renkHex: "#FF9500", localizationKey: "category.groceries"))
            modelContext.insert(Kategori(isim: "Restoran", ikonAdi: "fork.knife", tur: .gider, renkHex: "#FF3B30", localizationKey: "category.restaurant"))
            modelContext.insert(Kategori(isim: "Ulaşım", ikonAdi: "car.fill", tur: .gider, renkHex: "#5E5CE6", localizationKey: "category.transport"))
            modelContext.insert(Kategori(isim: "Faturalar", ikonAdi: "bolt.fill", tur: .gider, renkHex: "#FFCC00", localizationKey: "category.bills"))
            modelContext.insert(Kategori(isim: "Eğlence", ikonAdi: "film.fill", tur: .gider, renkHex: "#32ADE6", localizationKey: "category.entertainment"))
            modelContext.insert(Kategori(isim: "Sağlık", ikonAdi: "pills.fill", tur: .gider, renkHex: "#64D2FF", localizationKey: "category.health"))
            modelContext.insert(Kategori(isim: "Giyim", ikonAdi: "tshirt.fill", tur: .gider, renkHex: "#FF2D55", localizationKey: "category.clothing"))
            modelContext.insert(Kategori(isim: "Ev", ikonAdi: "house.fill", tur: .gider, renkHex: "#A2845E", localizationKey: "category.home"))
            modelContext.insert(Kategori(isim: "Hediye", ikonAdi: "gift.fill", tur: .gider, renkHex: "#BF5AF2", localizationKey: "category.gift"))
            modelContext.insert(Kategori(isim: "Kredi Ödemesi", ikonAdi: "creditcard.and.123", tur: .gider, renkHex: "#8E8E93", localizationKey: "category.loan_payment"))
            modelContext.insert(Kategori(isim: "Diğer", ikonAdi: "ellipsis.circle.fill", tur: .gider, renkHex: "#8E8E93", localizationKey: "category.other"))
        }
        
        // 2. Adım: Meta veri nesnesini oluştur ve bayrağını 'true' olarak ayarla.
        // Eğer zaten vardıysa, bu kod sadece bayrağı güncelleyecektir.
        let descriptorToUpdate = FetchDescriptor<AppMetadata>()
        if let metadataToUpdate = try? modelContext.fetch(descriptorToUpdate).first {
            metadataToUpdate.defaultCategoriesAdded = true
        } else {
            let newMetadata = AppMetadata(defaultCategoriesAdded: true)
            modelContext.insert(newMetadata)
        }

        // 3. Adım: Tüm değişiklikleri (hem kategoriler hem meta veri) kaydet.
        do {
            try modelContext.save()
            Logger.log("Meta veri bayrağı 'true' olarak ayarlandı ve veritabanı kaydedildi.", log: Logger.service, type: .info)
        } catch {
            Logger.log("Kategoriler veya meta veri kaydedilirken hata: \(error.localizedDescription)", log: Logger.data, type: .error)
        }
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
