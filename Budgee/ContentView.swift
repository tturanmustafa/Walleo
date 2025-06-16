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
                    // ... MainTabView içindeki switch bloğu ...
                case .panel:
                    // DashboardView'a artık modelContext'i veriyoruz.
                    NavigationStack { DashboardView(modelContext: modelContext) }
                case .takvim:
                    NavigationStack { TakvimView() }
                case .raporlar:
                    NavigationStack { RaporlarView() }
                case .ayarlar:
                    NavigationStack { AyarlarView() }
                }
            }.padding(.bottom, 70)

            HStack {
                CustomTabItem(iconName: "square.grid.2x2.fill", title: "Panel", sekme: .panel, seciliSekme: $seciliSekme)
                CustomTabItem(iconName: "calendar", title: "Takvim", sekme: .takvim, seciliSekme: $seciliSekme)
                Spacer().frame(width: 60)
                CustomTabItem(iconName: "chart.bar.xaxis", title: "Raporlar", sekme: .raporlar, seciliSekme: $seciliSekme)
                CustomTabItem(iconName: "gearshape.fill", title: "Ayarlar", sekme: .ayarlar, seciliSekme: $seciliSekme)
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
        // DÜZELTME: IslemEkleView artık parametre almıyor.
        .sheet(isPresented: $yeniIslemEkleShowing) {
            IslemEkleView()
        }
    }
}


struct CustomTabItem: View {
    let iconName: String
    let title: String
    let sekme: Sekme
    @Binding var seciliSekme: Sekme
    
    var body: some View {
        Button(action: {
            seciliSekme = sekme
        }) {
            VStack(spacing: 4) {
                Image(systemName: iconName).font(.title3)
                Text(title).font(.caption2)
            }.foregroundColor(seciliSekme == sekme ? .blue : .gray)
        }.frame(maxWidth: .infinity)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Islem.self, Kategori.self], inMemory: true)
        .environmentObject(AppSettings())
}
