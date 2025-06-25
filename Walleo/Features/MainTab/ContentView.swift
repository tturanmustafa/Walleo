import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var seciliSekme: Sekme = .panel
    @State private var yeniIslemEkleShowing = false
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appSettings: AppSettings

    enum Sekme: Hashable {
        case panel, hesaplar, butceler, raporlar
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $seciliSekme) {
                
                DashboardView(modelContext: modelContext)
                    .tabItem {
                        Label(LocalizedStringKey("tab.dashboard"), systemImage: "square.grid.2x2.fill")
                    }
                    .tag(Sekme.panel)

                HesaplarView()
                    .tabItem {
                        Label(LocalizedStringKey("accounts.title"), systemImage: "wallet.pass.fill")
                    }
                    .tag(Sekme.hesaplar)
                
                Text("").tabItem { Text("") }.disabled(true)

                ButcelerView()
                    .tabItem {
                        Label(LocalizedStringKey("tab.budgets"), systemImage: "chart.pie.fill")
                    }
                    .tag(Sekme.butceler)

                RaporlarView(modelContext: modelContext)
                    .tabItem {
                        Label(LocalizedStringKey("tab.reports"), systemImage: "chart.bar.xaxis")
                    }
                    .tag(Sekme.raporlar)
            }
            //.id(appSettings.languageCode)

            Button(action: {
                yeniIslemEkleShowing = true
            }) {
                ZStack {
                    Circle().fill(Color.blue).frame(width: 60, height: 60).shadow(radius: 4, y: 4)
                    Image(systemName: "plus").font(.title2.bold()).foregroundColor(.white)
                }
            }
            .offset(y: 0)
        }
        .ignoresSafeArea(.keyboard)
        .sheet(isPresented: $yeniIslemEkleShowing) {
            IslemEkleView()
        }
    }
}
