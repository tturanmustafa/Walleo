import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        MainTabView()
    }
}

struct MainTabView: View {
    @State private var seciliSekme: Sekme = .panel
    @State private var yeniIslemEkleShowing = false
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        ZStack(alignment: .bottom) {
            VStack {
                switch seciliSekme {
                case .panel:
                    NavigationStack { DashboardView(modelContext: modelContext) }
                case .takvim:
        // DEĞİŞİKLİK: TakvimView'a artık doğru context'i veriyoruz.
                    NavigationStack { TakvimView(modelContext: modelContext) }
                case .raporlar:
                    NavigationStack { RaporlarView() }
                case .ayarlar:
                    NavigationStack { AyarlarView() }
                }
            }.padding(.bottom, 70)

            HStack {
                // DEĞİŞİKLİK: Sabit metinler yerine anahtarları kullanıyoruz.
                CustomTabItem(iconName: "square.grid.2x2.fill", titleKey: "tab.dashboard", sekme: .panel, seciliSekme: $seciliSekme)
                CustomTabItem(iconName: "calendar", titleKey: "tab.calendar", sekme: .takvim, seciliSekme: $seciliSekme)
                Spacer().frame(width: 60)
                CustomTabItem(iconName: "chart.bar.xaxis", titleKey: "tab.reports", sekme: .raporlar, seciliSekme: $seciliSekme)
                CustomTabItem(iconName: "gearshape.fill", titleKey: "tab.settings", sekme: .ayarlar, seciliSekme: $seciliSekme)
            }
            .frame(height: 55)
            .padding(.horizontal)
            .background(.ultraThinMaterial)
            .cornerRadius(30)
            .padding(.horizontal)
            .shadow(radius: 5)
            .overlay(alignment: .center) {
                Button(action: {
                    yeniIslemEkleShowing = true
                }) {
                    ZStack {
                        Circle().fill(Color.blue).frame(width: 60, height: 60).shadow(radius: 4, y: 4)
                        Image(systemName: "plus").font(.title2.bold()).foregroundColor(.white)
                    }
                }
                .offset(y: -5)
            }
        }
        .ignoresSafeArea(.keyboard)
        .sheet(isPresented: $yeniIslemEkleShowing) {
            IslemEkleView()
        }
    }
}

struct CustomTabItem: View {
    let iconName: String
    let titleKey: LocalizedStringKey // DEĞİŞİKLİK: String yerine LocalizedStringKey alıyoruz.
    let sekme: Sekme
    @Binding var seciliSekme: Sekme
    
    var body: some View {
        Button(action: {
            seciliSekme = sekme
        }) {
            VStack(spacing: 4) {
                Image(systemName: iconName).font(.title3)
                Text(titleKey).font(.caption2) // Text artık anahtarı doğrudan kullanabilir.
            }.foregroundColor(seciliSekme == sekme ? .blue : .gray)
        }.frame(maxWidth: .infinity)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Islem.self, Kategori.self], inMemory: true)
        .environmentObject(AppSettings())
}
