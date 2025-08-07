// Walleo/Features/Accounts/HesaplarView.swift

import SwiftUI
import SwiftData

struct HesaplarView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appSettings: AppSettings
    @EnvironmentObject var entitlementManager: EntitlementManager // YENİ: EntitlementManager eklendi

    @State private var viewModel: HesaplarViewModel
    @State private var dayChangeTimer: Timer? // YENİ

    enum SheetTuru: Identifiable {
        case cuzdanEkle, krediKartiEkle, krediEkle
        case cuzdanDuzenle(Hesap), krediKartiDuzenle(Hesap), krediDuzenle(Hesap)
        var id: String {
            switch self {
            case .cuzdanEkle: "cuzdanEkle"
            case .krediKartiEkle: "krediKartiEkle"
            case .krediEkle: "krediEkle"
            case .cuzdanDuzenle(let h): "cuzdanDuzenle-\(h.id)"
            case .krediKartiDuzenle(let h): "krediKartiDuzenle-\(h.id)"
            case .krediDuzenle(let h): "krediDuzenle-\(h.id)"
            }
        }
    }
    @State private var gosterilecekSheet: SheetTuru?
    @State private var transferSheetGoster = false
    @State private var aktarimSheetiGoster = false
    @State private var showPaywall = false // YENİ: Paywall state

    init() {
        let container = try! ModelContainer(for: Hesap.self, Islem.self, Transfer.self)
        _viewModel = State(initialValue: HesaplarViewModel(modelContext: ModelContext(container)))
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.cuzdanHesaplari.isEmpty && viewModel.krediKartiHesaplari.isEmpty && viewModel.krediHesaplari.isEmpty {
                    ContentUnavailableView(LocalizedStringKey("accounts.empty.title"), systemImage: "wallet.pass", description: Text(LocalizedStringKey("accounts.empty.description")))
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 28) {
                            if !viewModel.cuzdanHesaplari.isEmpty {
                                hesapGrubu(titleKey: "accounts.group.wallets", hesaplar: viewModel.cuzdanHesaplari)
                            }
                            if !viewModel.krediKartiHesaplari.isEmpty {
                                hesapGrubu(titleKey: "accounts.group.credit_cards", hesaplar: viewModel.krediKartiHesaplari)
                            }
                            if !viewModel.krediHesaplari.isEmpty {
                                hesapGrubu(titleKey: "accounts.group.loans", hesaplar: viewModel.krediHesaplari)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 10)
                        .padding(.bottom, 90)
                    }
                    .background(Color(.systemBackground))
                }
            }
            .navigationTitle(LocalizedStringKey("accounts.title"))
            .toolbar { toolbarIcerigi() }
        }
        .onAppear {
            viewModel.modelContext = self.modelContext
            Task { await viewModel.hesaplamalariYap() }
            setupDayChangeTimer() // YENİ
        }
        .onDisappear {
            dayChangeTimer?.invalidate() // YENİ
            dayChangeTimer = nil
        }
        .sheet(item: $gosterilecekSheet, onDismiss: {
            Task { await viewModel.hesaplamalariYap() }
        }) { sheet in
            sheet.view.environmentObject(appSettings)
        }
        .sheet(isPresented: $transferSheetGoster) {
            HesaplarArasiTransferView().environmentObject(appSettings)
        }
        .sheet(isPresented: $aktarimSheetiGoster, onDismiss: {
            viewModel.aktarilacakHesap = nil
        }) {
            if let hesap = viewModel.aktarilacakHesap {
                HesapSecimAktarimView(
                    silinecekHesap: hesap,
                    uygunHesaplar: viewModel.uygunAktarimHesaplari,
                    onConfirm: { hedefHesap in
                        viewModel.hesabiSilVeIslemleriAktar(hedefHesap: hedefHesap)
                    }
                )
                .environmentObject(appSettings)
            }
        }
        // YENİ: Paywall sheet
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        // Mevcut alert'ler aynı kalacak...
        .alert(
            LocalizedStringKey("alert.delete_confirmation.title"),
            isPresented: .constant(viewModel.silinecekHesap != nil),
            presenting: viewModel.silinecekHesap
        ) { hesap in
            Button(role: .destructive) {
                viewModel.basitHesabiSil()
            } label: { Text("common.delete") }
            Button("common.cancel", role: .cancel) {
                viewModel.silinecekHesap = nil
            }
        } message: { hesap in
            let dilKodu = appSettings.languageCode
            guard let path = Bundle.main.path(forResource: dilKodu, ofType: "lproj"),
                  let languageBundle = Bundle(path: path) else { return Text(hesap.isim) }
            let key: String
            switch hesap.detay {
            case .cuzdan: key = "alert.delete_wallet.message_format"
            case .krediKarti: key = "alert.delete_credit_card.message_format"
            case .kredi: key = "alert.delete_loan.message_format"
            }
            let formatString = languageBundle.localizedString(forKey: key, value: "", table: nil)
            return Text(String(format: formatString, hesap.isim))
        }
        .alert(
            LocalizedStringKey("alert.no_eligible_account.title"),
            isPresented: $viewModel.uygunHesapYokUyarisiGoster
        ) {
            Button("common.ok", role: .cancel) {
                viewModel.uygunHesapYokUyarisiGoster = false
            }
        } message: {
            Text(LocalizedStringKey("alert.no_eligible_account.message"))
        }
        .onChange(of: viewModel.aktarilacakHesap) { _, newValue in
            aktarimSheetiGoster = (newValue != nil)
        }
        .alert(
            LocalizedStringKey("alert.no_eligible_wallet.title"),
            isPresented: $viewModel.sadeceCuzdanGerekliUyarisiGoster
        ) {
            Button("common.ok", role: .cancel) {
                viewModel.sadeceCuzdanGerekliUyarisiGoster = false
            }
        } message: {
            Text(LocalizedStringKey("alert.no_eligible_wallet.message"))
        }
    }

    @ViewBuilder
    private func hesapGrubu(titleKey: LocalizedStringKey, hesaplar: [GosterilecekHesap]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(titleKey).font(.title2.bold()).foregroundColor(.primary)
                Spacer()
                if titleKey == "accounts.group.wallets" || titleKey == "accounts.group.credit_cards" {
                    Button(action: { transferSheetGoster = true }) {
                        Image(systemName: "arrow.left.arrow.right.circle.fill").font(.title2).foregroundColor(.blue)
                    }
                }
            }
            .padding(.horizontal, 8)
            ForEach(hesaplar) { bilgi in
                NavigationLink(destination: navigationDestination(for: bilgi.hesap)) {
                    hesapKarti(for: bilgi)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }

    @ViewBuilder
    private func hesapKarti(for bilgi: GosterilecekHesap) -> some View {
        HesapKartView(
            gosterilecekHesap: bilgi,
            onEdit: { presentEditSheet(for: bilgi.hesap) },
            onDelete: { viewModel.silmeIsleminiBaslat(hesap: bilgi.hesap) }
        )
        .environmentObject(appSettings)
    }
    
    // YENİ: Güncellenmiş toolbar içeriği
    private func toolbarIcerigi() -> some ToolbarContent {
        ToolbarItemGroup(placement: .navigationBarTrailing) {
            Menu {
                Button(action: {
                    // Limit kontrolü
                    if viewModel.checkAndShowLimitWarning(for: .cuzdan, isPremium: entitlementManager.hasPremiumAccess) {
                        showPaywall = true // Limit aşıldıysa doğrudan paywall göster
                    } else {
                        gosterilecekSheet = .cuzdanEkle
                    }
                }) {
                    Label(LocalizedStringKey("accounts.add.wallet"), systemImage: "wallet.pass.fill")
                }
                Button(action: {
                    // Limit kontrolü
                    if viewModel.checkAndShowLimitWarning(for: .krediKarti, isPremium: entitlementManager.hasPremiumAccess) {
                        showPaywall = true // Limit aşıldıysa doğrudan paywall göster
                    } else {
                        gosterilecekSheet = .krediKartiEkle
                    }
                }) {
                    Label(LocalizedStringKey("accounts.add.credit_card"), systemImage: "creditcard.fill")
                }
                Button(action: {
                    // Limit kontrolü
                    if viewModel.checkAndShowLimitWarning(for: .kredi, isPremium: entitlementManager.hasPremiumAccess) {
                        showPaywall = true // Limit aşıldıysa doğrudan paywall göster
                    } else {
                        gosterilecekSheet = .krediEkle
                    }
                }) {
                    Label(LocalizedStringKey("accounts.add.loan"), systemImage: "banknote.fill")
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                    Text(LocalizedStringKey("button.add_account"))
                }
            }
        }
    }

    private func presentEditSheet(for hesap: Hesap) {
        switch hesap.detay {
        case .cuzdan: gosterilecekSheet = .cuzdanDuzenle(hesap)
        case .krediKarti: gosterilecekSheet = .krediKartiDuzenle(hesap)
        case .kredi: gosterilecekSheet = .krediDuzenle(hesap)
        }
    }

    @ViewBuilder
    private func navigationDestination(for hesap: Hesap) -> some View {
        switch hesap.detay {
        case .kredi:
            KrediDetayView(hesap: hesap, modelContext: self.modelContext)
        case .krediKarti:
            KrediKartiDetayView(kartHesabi: hesap, modelContext: self.modelContext)
        case .cuzdan:
            CuzdanDetayView(hesap: hesap)
        }
    }
    private func setupDayChangeTimer() {
        // Önce mevcut timer'ı temizle
        dayChangeTimer?.invalidate()
        
        // Şu anki tarih ve yarının başlangıcını hesapla
        let now = Date()
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now)!
        let midnightTomorrow = calendar.startOfDay(for: tomorrow)
        
        // Gece yarısına kadar olan süreyi hesapla
        let timeInterval = midnightTomorrow.timeIntervalSince(now)
        
        // Timer'ı kur
        dayChangeTimer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: false) { _ in
            Task { @MainActor in
                // Gün değişti, verileri güncelle
                await self.viewModel.hesaplamalariYap()
                
                // Bir sonraki gün değişimi için timer'ı yeniden kur
                self.setupDayChangeTimer()
            }
        }
    }
}

// Mevcut extension aynı kalacak
extension HesaplarView.SheetTuru {
    @ViewBuilder
    var view: some View {
        switch self {
        case .cuzdanEkle: BasitHesapEkleView()
        case .krediKartiEkle: KrediKartiEkleView()
        case .krediEkle: KrediEkleView()
        case .cuzdanDuzenle(let hesap): BasitHesapEkleView(duzenlenecekHesap: hesap)
        case .krediKartiDuzenle(let hesap): KrediKartiEkleView(duzenlenecekHesap: hesap)
        case .krediDuzenle(let hesap): KrediEkleView(duzenlenecekHesap: hesap)
        }
    }
}
