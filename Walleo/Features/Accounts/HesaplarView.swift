import SwiftUI
import SwiftData

struct HesaplarView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appSettings: AppSettings
    
    @State private var viewModel: HesaplarViewModel?
    
    enum SheetTuru: Identifiable {
        case cuzdanEkle, krediKartiEkle, krediEkle
        case cuzdanDuzenle(Hesap), krediKartiDuzenle(Hesap), krediDuzenle(Hesap)
        
        var id: String {
            switch self {
            case .cuzdanEkle: "cuzdanEkle"
            case .krediKartiEkle: "krediKartiEkle"
            case .krediEkle: "krediEkle"
            case .cuzdanDuzenle(let hesap): "cuzdanDuzenle-\(hesap.id)"
            case .krediKartiDuzenle(let hesap): "krediKartiDuzenle-\(hesap.id)"
            case .krediDuzenle(let hesap): "krediDuzenle-\(hesap.id)"
            }
        }
    }
    @State private var gosterilecekSheet: SheetTuru?
    
    @State private var silinecekHesap: Hesap?

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel = viewModel {
                    hesapListesi(viewModel: viewModel)
                        .overlay {
                            if viewModel.gosterilecekHesaplar.isEmpty {
                                ContentUnavailableView(LocalizedStringKey("accounts.empty.title"), systemImage: "wallet.pass", description: Text(LocalizedStringKey("accounts.empty.description")))
                            }
                        }
                } else {
                    ProgressView()
                }
            }
            .navigationTitle(LocalizedStringKey("accounts.title"))
            .toolbar { toolbarIcerigi() }
        }
        .sheet(item: $gosterilecekSheet, onDismiss: {
            Task { await viewModel?.hesaplamalariYap() }
        }) { sheet in
            sheet.view
                .environmentObject(appSettings)
        }
        .task {
            if viewModel == nil {
                viewModel = HesaplarViewModel(modelContext: self.modelContext)
                await viewModel?.hesaplamalariYap()
            }
        }
        .alert(
            LocalizedStringKey("alert.delete_confirmation.title"),
            isPresented: Binding(isPresented: $silinecekHesap),
            presenting: silinecekHesap
        ) { hesap in
            Button(role: .destructive) {
                viewModel?.hesabiSil(hesap: hesap)
            } label: {
                Text("common.delete")
            }
        } message: { hesap in
            let dilKodu = appSettings.languageCode
            guard let path = Bundle.main.path(forResource: dilKodu, ofType: "lproj"),
                  let languageBundle = Bundle(path: path) else {
                return Text(hesap.isim) // Fallback
            }
            
            let key: String
            switch hesap.detay {
            case .cuzdan:
                key = "alert.delete_wallet.message_format"
            case .krediKarti:
                key = "alert.delete_credit_card.message_format"
            case .kredi:
                key = "alert.delete_loan.message_format"
            }
            
            let formatString = languageBundle.localizedString(forKey: key, value: "", table: nil)
            return Text(String(format: formatString, hesap.isim))
        }
    }
    
    // GÜNCELLENMİŞ FONKSİYON
    private func hesapListesi(viewModel: HesaplarViewModel) -> some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(viewModel.gosterilecekHesaplar) { bilgi in
                    // GÜNCELLEME: Artık cüzdan tipi de bir NavigationLink içinde.
                    if case .kredi = bilgi.hesap.detay {
                        NavigationLink(destination: KrediDetayView(hesap: bilgi.hesap, modelContext: self.modelContext)) {
                            hesapKarti(for: bilgi, viewModel: viewModel)
                        }
                        .buttonStyle(.plain)
                    } else if case .krediKarti = bilgi.hesap.detay {
                        NavigationLink(destination: KrediKartiDetayView(kartHesabi: bilgi.hesap, modelContext: self.modelContext)) {
                            hesapKarti(for: bilgi, viewModel: viewModel)
                        }
                        .buttonStyle(.plain)
                    } else {
                        // YENİ: Cüzdan tipi için NavigationLink eklendi.
                        NavigationLink(destination: CuzdanDetayView(hesap: bilgi.hesap)) {
                            hesapKarti(for: bilgi, viewModel: viewModel)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding()
        }
    }
    
    @ViewBuilder
    private func hesapKarti(for bilgi: GosterilecekHesap, viewModel: HesaplarViewModel) -> some View {
        HesapKartView(
            gosterilecekHesap: bilgi,
            onEdit: { presentEditSheet(for: bilgi.hesap) },
            onDelete: { silinecekHesap = bilgi.hesap }
        )
        .environmentObject(appSettings)
    }
    
    private func toolbarIcerigi() -> some ToolbarContent {
        ToolbarItemGroup(placement: .navigationBarTrailing) {
            // DİKKAT: Sadece Menu'nün label'ı değişti
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
    private func detayEkraniniGetir(hesap: Hesap) -> some View {
        switch hesap.detay {
        case .kredi: KrediDetayView(hesap: hesap, modelContext: self.modelContext)
        case .krediKarti: KrediKartiDetayView(kartHesabi: hesap, modelContext: self.modelContext)
        default:
            // Bu case normalde cüzdan için çağrılmayacak ama güvenlik için burada.
            let title = String.localizedStringWithFormat(NSLocalizedString("account_details.generic_title", comment: ""), hesap.isim)
            Text(title)
        }
    }
}

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
