import SwiftUI
import SwiftData

@main
struct BudgeeApp: App {
    @StateObject private var appSettings = AppSettings()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appSettings)
                .preferredColorScheme(appSettings.colorScheme)
                // YENİ VE KRİTİK EKLEME:
                // AppSettings'teki dil kodunu uygulamanın geneline enjekte ediyoruz.
                // Bu satır sayesinde dil anlık olarak değişecektir.
                .environment(\.locale, Locale(identifier: appSettings.languageCode))
        }
        .modelContainer(for: [Islem.self, Kategori.self])
    }
}
