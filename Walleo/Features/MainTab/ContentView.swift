// GÜNCELLEME: ContentView.swift

import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var seciliSekme: Sekme = .panel
    @State private var yeniIslemEkleShowing = false
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var entitlementManager: EntitlementManager
    @EnvironmentObject var appSettings: AppSettings
    
    @State private var hesapYokUyarisiGoster = false
    @State private var paywallGosteriliyor = false
    @Query private var kullanilabilirHesaplar: [Hesap]
    @State private var showPaywall = false                               // ⬅️ EKLENDİ

    
    init() {
        let predicate = #Predicate<Hesap> { hesap in
            true
        }
        _kullanilabilirHesaplar = Query(filter: predicate)
    }

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

                // GÜNCELLEME: Hatalı olan çağrı düzeltildi.
                // RaporlarView artık modelContext'i parametre olarak almıyor.
                RaporlarView()
                    .tabItem {
                        Label(LocalizedStringKey("tab.reports"), systemImage: "chart.bar.xaxis")
                    }
                    .tag(Sekme.raporlar)
            }

            Button(action: {
                let islemHesaplari = kullanilabilirHesaplar.filter {
                    if case .kredi = $0.detay { return false }; return true
                }
                
                if islemHesaplari.isEmpty {
                    hesapYokUyarisiGoster = true
                } else {
                    yeniIslemEkleShowing = true
                }
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
                .environmentObject(appSettings)
        }
        .alert(
            LocalizedStringKey("alert.no_accounts.title"),
            isPresented: $hesapYokUyarisiGoster
        ) {
            Button(LocalizedStringKey("alert.no_accounts.add_account_button")) {
                seciliSekme = .hesaplar
            }
            Button(LocalizedStringKey("common.cancel"), role: .cancel) { }
        } message: {
            Text("alert.no_accounts.message")
        }
        .onAppear {
            Task {
                await entitlementManager.refresh()
                if entitlementManager.isLoaded && !entitlementManager.hasPremiumAccess {
                    paywallGosteriliyor = true
                }
            }
        }
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .onChange(of: entitlementManager.hasPremiumAccess) { yeniDurum in
            if yeniDurum { showPaywall = false }
        }
    }
}
