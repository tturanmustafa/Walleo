import SwiftUI
import SwiftData

struct HesaplarView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appSettings: AppSettings

    // GÜNCELLENDİ: ViewModel artık @State olarak ve init içinde kuruluyor. Bu daha stabil bir yöntem.
    @State private var viewModel: HesaplarViewModel

    // YENİ: Sheet'leri ve Alert'leri yönetmek için enum yapısı ve state'ler.
    // Bu yapı, hem ekleme hem düzenleme sheet'lerini tek bir yerden yönetmemizi sağlar.
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
    @State private var aktarimSheetiGoster = false // YENİ: İşlem aktarım sheet'i için state

    // GÜNCELLENDİ: init metodu viewModel'ı kuracak şekilde güncellendi
    init() {
        // ViewModel'ı bu view'a özel bir @State olarak başlatıyoruz.
        // Bu, SwiftData context'inin view yeniden çizildiğinde kaybolmamasını sağlar.
        // Geçici bir container ile başlatıyoruz, onAppear içinde gerçeğiyle değiştireceğiz.
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
            // View ekrana geldiğinde, environment'tan gelen doğru modelContext'i ViewModel'e atıyoruz.
            viewModel.modelContext = self.modelContext
            Task { await viewModel.hesaplamalariYap() }
        }
        .sheet(item: $gosterilecekSheet, onDismiss: {
            Task { await viewModel.hesaplamalariYap() }
        }) { sheet in
            sheet.view.environmentObject(appSettings)
        }
        .sheet(isPresented: $transferSheetGoster) {
            HesaplarArasiTransferView().environmentObject(appSettings)
        }
        // YENİ: İşlem Aktarım Ekranını gösteren sheet
        .sheet(isPresented: $aktarimSheetiGoster, onDismiss: {
            viewModel.aktarilacakHesap = nil // Sheet kapanınca state'i temizle
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
        // GÜNCELLENDİ: Bu alert artık SADECE işlemi olmayan hesaplar için çalışacak
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
        // YENİ: Uygun hesap bulunamadığında gösterilecek uyarı
        .alert(
            LocalizedStringKey("alert.no_eligible_account.title"),
            isPresented: $viewModel.uygunHesapYokUyarisiGoster
        ) {
            Button("common.ok", role: .cancel) {
                viewModel.uygunHesapYokUyarisiGoster = false // Uyarıyı kapat
            }
        } message: {
            Text(LocalizedStringKey("alert.no_eligible_account.message"))
        }
        // YENİ: ViewModel'deki değişiklikleri dinleyip sheet'i tetikleyen yapı
        .onChange(of: viewModel.aktarilacakHesap) { _, newValue in
            aktarimSheetiGoster = (newValue != nil)
        }
        .alert(
            LocalizedStringKey("alert.no_eligible_wallet.title"),
            isPresented: $viewModel.sadeceCuzdanGerekliUyarisiGoster
        ) {
            Button("common.ok", role: .cancel) {
                viewModel.sadeceCuzdanGerekliUyarisiGoster = false // Uyarıyı kapat
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
            // GÜNCELLENDİ: onDelete artık ViewModel'deki yeni akıllı fonksiyonu çağırıyor
            onDelete: { viewModel.silmeIsleminiBaslat(hesap: bilgi.hesap) }
        )
        .environmentObject(appSettings)
    }
    private func toolbarIcerigi() -> some ToolbarContent {
        ToolbarItemGroup(placement: .navigationBarTrailing) {
            Menu {
                Button(action: { gosterilecekSheet = .cuzdanEkle }) {
                    Label(LocalizedStringKey("accounts.add.wallet"), systemImage: "wallet.pass.fill")
                }
                Button(action: { gosterilecekSheet = .krediKartiEkle }) {
                    Label(LocalizedStringKey("accounts.add.credit_card"), systemImage: "creditcard.fill")
                }
                Button(action: { gosterilecekSheet = .krediEkle }) {
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
}

// Bu extension'da değişiklik yok
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
