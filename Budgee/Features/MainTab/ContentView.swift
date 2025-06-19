import SwiftUI
import SwiftData

struct ContentView: View {
    // Sekme seçimi için enum'ı güncelliyoruz, artık 'ekle' diye bir durum yok.
    enum Sekme: Hashable {
        case panel, hesaplar, butceler, raporlar
    }
    
    @State private var seciliSekme: Sekme = .panel
    @State private var yeniIslemEkleShowing = false
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        // YENİ YAPI: ZStack ile TabView ve butonu üst üste bindiriyoruz.
        ZStack(alignment: .bottom) {
            // 1. KATMAN: Standart TabView
            TabView(selection: $seciliSekme) {
                
                DashboardView(modelContext: modelContext)
                    .tabItem {
                        Label(LocalizedStringKey("tab.dashboard"), systemImage: "square.grid.2x2.fill")
                    }
                    .tag(Sekme.panel)

                HesaplarView()
                    .tabItem {
                        Label("Hesaplar", systemImage: "wallet.pass.fill")
                    }
                    .tag(Sekme.hesaplar)
                
                // ORTADAKİ BOŞLUK İÇİN GİZLİ BİR SEKME
                // Bu sekme, butonun arkasında bir boşluk hissi yaratır.
                Text("").tabItem { Text("") }.tag(4) // Bu sekmeyi boş bırakıyoruz

                ButcelerView()
                    .tabItem {
                        Label("Bütçeler", systemImage: "chart.pie.fill")
                    }
                    .tag(Sekme.butceler)

                RaporlarView(modelContext: modelContext)
                    .tabItem {
                        Label(LocalizedStringKey("tab.reports"), systemImage: "chart.bar.xaxis")
                    }
                    .tag(Sekme.raporlar)
            }
            
            // 2. KATMAN: Özel '+' Butonumuz
            Button(action: {
                yeniIslemEkleShowing = true
            }) {
                ZStack {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 60, height: 60)
                        .shadow(radius: 4, y: 4)
                    
                    Image(systemName: "plus")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                }
            }
            // Butonu dikey olarak yukarı kaydırarak Tab Bar'ın üzerine taşıyoruz.
            .offset(y: 0)
        }
        .ignoresSafeArea(.keyboard) // Klavyenin ZStack'i yukarı itmesini engeller.
        .sheet(isPresented: $yeniIslemEkleShowing) {
            IslemEkleView()
        }
    }
}
