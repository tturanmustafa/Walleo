// Dosya Adı: BudgeeApp.swift

import SwiftUI
import SwiftData

@main
struct BudgeeApp: App {
    @StateObject private var appSettings = AppSettings()
    let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try ModelContainer(for: Hesap.self, Islem.self, Kategori.self)
        } catch {
            fatalError("ModelContainer oluşturulamadı: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appSettings)
                .preferredColorScheme(appSettings.colorScheme)
                .environment(\.locale, Locale(identifier: appSettings.languageCode))
                .task {
                    await addDefaultCategoriesIfNeeded()
                }
        }
        .modelContainer(modelContainer)
    }
    
    @MainActor
    private func addDefaultCategoriesIfNeeded() async {
        let modelContext = modelContainer.mainContext
        do {
            let descriptor = FetchDescriptor<Kategori>()
            let existingCategories = try modelContext.fetch(descriptor)
            
            if existingCategories.isEmpty {
                // --- KESİN ÇÖZÜM: TÜM KATEGORİLER BURADA OLUŞTURULUYOR ---
                // Gelir Kategorileri
                modelContext.insert(Kategori(isim: "Maaş", ikonAdi: "dollarsign.circle.fill", tur: .gelir, renkHex: "#34C759", localizationKey: "category.salary"))
                modelContext.insert(Kategori(isim: "Ek Gelir", ikonAdi: "chart.pie.fill", tur: .gelir, renkHex: "#007AFF", localizationKey: "category.extra_income"))
                modelContext.insert(Kategori(isim: "Yatırım", ikonAdi: "chart.line.uptrend.xyaxis", tur: .gelir, renkHex: "#AF52DE", localizationKey: "category.investment"))

                // Gider Kategorileri
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
                
                try modelContext.save()
            }
        } catch {
            print("Varsayılan kategoriler kontrol edilirken hata oluştu: \(error)")
        }
    }
}
