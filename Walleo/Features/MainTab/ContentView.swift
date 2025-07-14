import SwiftUI
import SwiftData

// +++ YENİ EKLENEN YARDIMCI VIEW'LAR (DAHA FAZLA MENÜSÜ İÇİN) +++

// 1. "Bütçeler" ve "Raporlar" butonlarının stilini belirleyen yapı.
struct FloatingActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .padding()
            .frame(width: 160)
            .background(.regularMaterial) // Hafif bulanık, modern bir arka plan
            .foregroundColor(.primary)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(), value: configuration.isPressed)
    }
}

// 2. "Daha Fazla"ya tıklandığında beliren, animasyonlu butonları içeren menü.
struct FloatingActionMenu: View {
    @Binding var seciliSekme: ContentView.Sekme
    @Binding var isShowing: Bool
    
    // Butonların kademeli olarak görünmesi için state'ler
    @State private var showButtons = [false, false]

    var body: some View {
        VStack(spacing: 16) {
            // Raporlar Butonu
            Button(action: {
                seciliSekme = .raporlar
                isShowing = false
            }) {
                Label("tab.reports", systemImage: "chart.bar.xaxis")
            }
            .buttonStyle(FloatingActionButtonStyle())
            .opacity(showButtons[0] ? 1 : 0)
            .offset(y: showButtons[0] ? 0 : 20)
            
            // Bütçeler Butonu
            Button(action: {
                seciliSekme = .butceler
                isShowing = false
            }) {
                Label("tab.budgets", systemImage: "chart.pie.fill")
            }
            .buttonStyle(FloatingActionButtonStyle())
            .opacity(showButtons[1] ? 1 : 0)
            .offset(y: showButtons[1] ? 0 : 20)
        }
        .onAppear {
            // Menü açıldığında butonları güzel bir animasyonla göster
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8, blendDuration: 0).delay(0.1)) {
                showButtons[0] = true
            }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8, blendDuration: 0).delay(0.05)) {
                showButtons[1] = true
            }
        }
    }
}


// --- ANA İÇERİK GÖRÜNÜMÜ ---

struct ContentView: View {
    @State private var seciliSekme: Sekme = .panel
    
    // --- DEĞİŞİKLİK: "Daha Fazla" menüsü için state'ler ---
    @State private var dahaFazlaShowing = false
    
    @State private var yeniIslemEkleShowing = false
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var entitlementManager: EntitlementManager
    @EnvironmentObject var appSettings: AppSettings
    
    @State private var hesapYokUyarisiGoster = false
    @Query private var kullanilabilirHesaplar: [Hesap]
    @State private var showPaywall = false
    
    private var isMoreTabSelected: Bool {
        switch seciliSekme {
        case .butceler, .raporlar:
            return true // Eğer Bütçeler veya Raporlar seçiliyse true döner
        default:
            return false // Diğer tüm sekmeler için false döner
        }
    }

    init() {
        let krediTuruRawValue = HesapTuru.kredi.rawValue
        let predicate = #Predicate<Hesap> { hesap in
            hesap.hesapTuruRawValue != krediTuruRawValue
        }
        _kullanilabilirHesaplar = Query(filter: predicate)
    }

    // "Daha Fazla" butonu artık bir sekme değil, sadece menüyü açan bir eylem olduğu için
    // enum'dan kaldırıldı. Bütçeler ve Raporlar hala programatik geçiş için mevcut.
    enum Sekme: Hashable {
        case panel, hesaplar, takvim, butceler, raporlar
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // --- DEĞİŞİKLİK: TabView artık gizli sekmeler içeriyor ---
            // "Bütçeler" ve "Raporlar" sekmeleri artık görünür değil,
            // ama "Daha Fazla" menüsünden programatik olarak seçilebilir durumdalar.
            TabView(selection: $seciliSekme) {
                DashboardView(modelContext: modelContext)
                    .tag(Sekme.panel)
                HesaplarView()
                    .tag(Sekme.hesaplar)
                TakvimView(modelContext: modelContext)
                    .tag(Sekme.takvim)
                ButcelerView()
                    .tag(Sekme.butceler)
                RaporlarView()
                    .tag(Sekme.raporlar)
            }
            
            // --- DEĞİŞİKLİK: Özel TabBar ve "+" Butonu ---
            VStack(spacing: 0) {
                Spacer() // İçeriği yukarı iter
                HStack(alignment: .bottom) {
                    TabButton(iconName: "square.grid.2x2.fill", labelKey: "tab.dashboard", sekme: .panel, seciliSekme: $seciliSekme)
                    TabButton(iconName: "wallet.pass.fill", labelKey: "accounts.title", sekme: .hesaplar, seciliSekme: $seciliSekme)
                    
                    addTransactionButton
                    
                    TabButton(iconName: "calendar", labelKey: "tab.calendar", sekme: .takvim, seciliSekme: $seciliSekme)
                    
                    // "Daha Fazla" butonu artık sadece menüyü açıyor
                    Button(action: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            dahaFazlaShowing.toggle()
                        }
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 22))
                                .frame(height: 24)
                            Text("tab.more")
                                .font(.caption)
                        }
                        .foregroundColor(dahaFazlaShowing || isMoreTabSelected ? .accentColor : .secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.top, 25)
                .frame(height: 50 + safeAreaInsets.bottom)
                .contentShape(Rectangle()) // <--- BU SATIRI EKLEYİN
            }

            // --- DEĞİŞİKLİK: Yeni "Daha Fazla" menüsü burada gösteriliyor ---
            if dahaFazlaShowing {
                // Menü dışına tıklandığında kapatmak için yarı saydam arka plan
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            dahaFazlaShowing = false
                        }
                    }
                
                // Animasyonlu butonların kendisi
                FloatingActionMenu(seciliSekme: $seciliSekme, isShowing: $dahaFazlaShowing)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(.trailing, 20)
                    .padding(.bottom, 90) // Navigasyon çubuğunun üzerinde konumlandır
                    .transition(.opacity.combined(with: .offset(y: 50)))
            }
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
    }

    // "+" Butonu
    var addTransactionButton: some View {
        Button(action: {
            if kullanilabilirHesaplar.isEmpty {
                hesapYokUyarisiGoster = true
            } else {
                yeniIslemEkleShowing = true
            }
        }) {
            ZStack {
                Circle().fill(Color.blue).frame(width: 60, height: 60).shadow(radius: 4, y: 4)
                Image(systemName: "plus").font(.title.bold()).foregroundColor(.white)
            }
        }
        .frame(maxWidth: .infinity)
        .offset(y: 0)
    }

    // Özel Tab Bar butonu için yardımcı View
    struct TabButton: View {
        let iconName: String
        let labelKey: LocalizedStringKey
        let sekme: Sekme
        @Binding var seciliSekme: Sekme
        
        var body: some View {
            Button(action: { seciliSekme = sekme }) {
                VStack(spacing: 4) {
                    Image(systemName: iconName)
                        .font(.system(size: 22))
                        .frame(height: 24)
                    Text(labelKey)
                        .font(.caption)
                }
                .foregroundColor(seciliSekme == sekme ? .accentColor : .secondary)
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    // Güvenli alan boşluklarını almak için yardımcı
    private var safeAreaInsets: UIEdgeInsets {
        (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.windows.first?.safeAreaInsets ?? .zero
    }
}
