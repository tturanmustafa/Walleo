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
        }
        .modelContainer(for: [Islem.self, Kategori.self])
    }
}
