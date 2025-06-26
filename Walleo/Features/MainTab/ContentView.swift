import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var seciliSekme: Sekme = .panel
    @State private var yeniIslemEkleShowing = false
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appSettings: AppSettings
    
    // YENİ: Uyarıları yönetmek için state'ler
    @State private var hesapYokUyarisiGoster = false

    // SwiftData'dan kullanılabilir hesapları çekmek için Query
    @Query private var kullanilabilirHesaplar: [Hesap]
    
    init() {
        // Query'yi sadece Cüzdan ve Kredi Kartı tiplerini içerecek şekilde filtreliyoruz
        let predicate = #Predicate<Hesap> { hesap in
            // Bu kısım Hesap modelindeki 'detay' enum'ının yapısına göre ayarlanmalı.
            // Örnek bir filtreleme varsayımı:
            // hesap.tur == "cuzdan" || hesap.tur == "krediKarti"
            // Bizim projemizde bu kontrolü doğrudan yapamıyoruz, bu yüzden şimdilik tüm hesapları alıp
            // butonda filtreleyeceğiz.
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

                RaporlarView(modelContext: modelContext)
                    .tabItem {
                        Label(LocalizedStringKey("tab.reports"), systemImage: "chart.bar.xaxis")
                    }
                    .tag(Sekme.raporlar)
            }

            Button(action: {
                // YENİ KONTROL: İşlem eklenebilecek bir hesap var mı?
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
        // YENİ ALERT
        .alert(
            LocalizedStringKey("alert.no_accounts.title"),
            isPresented: $hesapYokUyarisiGoster
        ) {
            Button(LocalizedStringKey("alert.no_accounts.add_account_button")) {
                // Kullanıcıyı Hesaplar sekmesine yönlendir
                seciliSekme = .hesaplar
            }
            Button(LocalizedStringKey("common.cancel"), role: .cancel) { }
        } message: {
            Text("alert.no_accounts.message")
        }
    }
}
