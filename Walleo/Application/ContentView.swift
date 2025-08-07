import SwiftUI
import SwiftData

// +++ DEĞİŞİKLİK YOK: Bu yapı aynı kalıyor +++
struct FloatingActionButtonStyle: ButtonStyle {
    var isPremium: Bool = false  // ← YENİ SATIR
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .padding()
            .frame(width: 160)
            .background(isPremium ? Color(.systemGray5) : Color(.systemGray6))
            .foregroundColor(.primary) // ← DEĞİŞTİRİLEN SATIR
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(), value: configuration.isPressed)
    }
}

// +++ DEĞİŞİKLİK YOK: Bu yapı aynı kalıyor +++
struct FloatingActionMenu: View {
    @Binding var seciliSekme: ContentView.Sekme
    @Binding var isShowing: Bool
    @Binding var showPaywall: Bool
    @EnvironmentObject var entitlementManager: EntitlementManager
    
    @State private var showButtons = [false, false, false]

    var body: some View {
        VStack(spacing: 16) {
            // Normal Raporlar - Herkes erişebilir
            Button(action: { seciliSekme = .raporlar; isShowing = false }) {
                Label("tab.reports", systemImage: "chart.bar.xaxis")
            }
            .buttonStyle(FloatingActionButtonStyle())
            .opacity(showButtons[1] ? 1 : 0)
            .offset(y: showButtons[1] ? 0 : 20)
            
            // Detaylı Raporlar - Premium özellik
            Button(action: {
                seciliSekme = .detayliRaporlar
                isShowing = false
            }) {
                Label("reports.detailed.title", systemImage: "magnifyingglass")
            }
            .buttonStyle(FloatingActionButtonStyle())
            .opacity(showButtons[0] ? 1 : 0)
            .offset(y: showButtons[0] ? 0 : 20)
            
            // Bütçeler - Premium özellik
            Button(action: {
                seciliSekme = .butceler
                isShowing = false
            }) {
                Label("tab.budgets", systemImage: "chart.pie.fill")
            }
            .buttonStyle(FloatingActionButtonStyle())
            .opacity(showButtons[2] ? 1 : 0)
            .offset(y: showButtons[2] ? 0 : 20)
        }
        .onAppear {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8, blendDuration: 0).delay(0.15)) { showButtons[0] = true }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8, blendDuration: 0).delay(0.1)) { showButtons[1] = true }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8, blendDuration: 0).delay(0.05)) { showButtons[2] = true }
        }
    }
}

struct ContentView: View {
    @State private var seciliSekme: Sekme = .panel
    
    @State private var dahaFazlaShowing = false
    @State private var yeniIslemEkleShowing = false
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var entitlementManager: EntitlementManager
    @EnvironmentObject var appSettings: AppSettings
    @State private var hesapYokUyarisiGoster = false
    @Query private var cuzdanHesaplari: [Hesap]
    @State private var acilacakSheet: HesaplarView.SheetTuru?

    @Query private var kullanilabilirHesaplar: [Hesap]
    @State private var showPaywall = false
    
    private var isMoreTabSelected: Bool {
        switch seciliSekme {
        case .butceler, .raporlar, .detayliRaporlar:
            return true
        default:
            return false
        }
    }

    init() {
        // Mevcut sorgunuz aynı kalıyor
        let krediTuruRawValue = HesapTuru.kredi.rawValue
        let predicate = #Predicate<Hesap> { hesap in
            hesap.hesapTuruRawValue != krediTuruRawValue
        }
        _kullanilabilirHesaplar = Query(filter: predicate)
        
        // --- 🔥 2. ADIM: YENİ SORGUMUZU INIT İÇİNDE BAŞLATIN 🔥 ---
        // Yeni sorgumuzun filtresini burada tanımlıyoruz.
        let cuzdanTuruRawValue = HesapTuru.cuzdan.rawValue
        let cuzdanPredicate = #Predicate<Hesap> { hesap in
            hesap.hesapTuruRawValue == cuzdanTuruRawValue
        }
        _cuzdanHesaplari = Query(filter: cuzdanPredicate)
    }

    enum Sekme: Hashable {
        case panel, hesaplar, takvim, butceler, raporlar, detayliRaporlar
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Ana içerik
            Group {
                if seciliSekme == .panel || seciliSekme == .hesaplar || seciliSekme == .takvim {
                    // Normal tab'lar için TabView kullan
                    TabView(selection: $seciliSekme) {
                        NavigationStack { DashboardView(modelContext: modelContext) }
                            .tag(Sekme.panel)
                        
                        NavigationStack { HesaplarView() }
                            .tag(Sekme.hesaplar)
                            
                        NavigationStack { TakvimView(modelContext: modelContext) }
                            .tag(Sekme.takvim)
                    }
                } else {
                    // "Daha Fazla" menüsünden seçilenler için doğrudan göster
                    // --- 🔥 DEĞİŞİKLİK BURADA BAŞLIYOR 🔥 ---
                    Group {
                        switch seciliSekme {
                        case .butceler:
                            NavigationStack {
                                ButcelerView()
                            }
                        case .raporlar:
                            NavigationStack {
                                RaporlarView()
                            }
                        case .detayliRaporlar:
                            NavigationStack {
                                DetayliRaporlarView()
                            }
                        default:
                            EmptyView()
                        }
                    }
                    .padding(.bottom, 80)
                }
            }
            
            // Custom Tab Bar (aynı kalacak)
            VStack(spacing: 0) {
                Spacer()
                HStack(alignment: .bottom) {
                    TabButton(iconName: "square.grid.2x2.fill", labelKey: "tab.dashboard", sekme: .panel, seciliSekme: $seciliSekme)
                    TabButton(iconName: "wallet.pass.fill", labelKey: "accounts.title", sekme: .hesaplar, seciliSekme: $seciliSekme)
                    addTransactionButton
                    TabButton(iconName: "calendar", labelKey: "tab.calendar", sekme: .takvim, seciliSekme: $seciliSekme)
                    
                    // Daha Fazla Butonu
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
                .padding(.top, 10)
                .frame(height: 30 + safeAreaInsets.bottom)
                .background(Color(.systemBackground))
                .contentShape(Rectangle())
            }

            // Floating Menu Overlay (aynı kalacak)
            if dahaFazlaShowing {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            dahaFazlaShowing = false
                        }
                    }
                
                FloatingActionMenu(seciliSekme: $seciliSekme, isShowing: $dahaFazlaShowing, showPaywall: $showPaywall)  // ← DEĞİŞTİ
                    .environmentObject(entitlementManager)  // ← YENİ SATIR
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(.trailing, 20)
                    .padding(.bottom, 90)
                    .transition(.opacity.combined(with: .offset(y: 50)))
            }
        }
        .ignoresSafeArea(.keyboard)
        .sheet(isPresented: $yeniIslemEkleShowing) {
            IslemEkleView()
                .environmentObject(appSettings)
        }
        .ignoresSafeArea(.keyboard)
        // 🔥 3. ADIM: BU YENİ SHEET MODIFIER'INI EKLEYİN
        .sheet(item: $acilacakSheet) { sheet in
            sheet.view
                .environmentObject(appSettings)
        }
        // Paywall sheet'i  ← YENİ
        .sheet(isPresented: $showPaywall) {  // ← YENİ
            PaywallView()  // ← YENİ
        }
        .alert(
            LocalizedStringKey("alert.no_accounts.title"),
            isPresented: $hesapYokUyarisiGoster
        ) {
            Button(LocalizedStringKey("alert.no_accounts.add_account_button")) {
                // 🔥 4. ADIM: SADECE SHEET'İ AÇMA KOMUTU VERİN
                // Sekmeyi değiştirmeye gerek yok, sheet zaten her yerden açılabilir.
                acilacakSheet = .cuzdanEkle
            }
            Button("common.cancel", role: .cancel) { }
        } message: {
            Text(LocalizedStringKey("alert.no_wallet.message"))
        }
    }

    // "+" Butonu
    var addTransactionButton: some View {
        Button(action: {
            if cuzdanHesaplari.isEmpty {
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
