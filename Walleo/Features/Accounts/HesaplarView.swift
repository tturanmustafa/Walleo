// Walleo/Features/Accounts/HesaplarView.swift

import SwiftUI
import SwiftData

struct HesaplarView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appSettings: AppSettings

    @State private var viewModel: HesaplarViewModel?

    // Sheet'leri ve Alert'leri yönetmek için kullanılan State'ler
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
                    if viewModel.cuzdanHesaplari.isEmpty && viewModel.krediKartiHesaplari.isEmpty && viewModel.krediHesaplari.isEmpty {
                        ContentUnavailableView(LocalizedStringKey("accounts.empty.title"), systemImage: "wallet.pass", description: Text(LocalizedStringKey("accounts.empty.description")))
                    } else {
                        // ANA GÖRÜNÜM: List yerine ScrollView kullanarak tam stil kontrolü sağlıyoruz.
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 28) { // Gruplar arasına daha fazla boşluk
                                // Cüzdanlar Grubu
                                if !viewModel.cuzdanHesaplari.isEmpty {
                                    hesapGrubu(titleKey: "accounts.group.wallets", hesaplar: viewModel.cuzdanHesaplari, viewModel: viewModel)
                                }

                                // Kredi Kartları Grubu
                                if !viewModel.krediKartiHesaplari.isEmpty {
                                    hesapGrubu(titleKey: "accounts.group.credit_cards", hesaplar: viewModel.krediKartiHesaplari, viewModel: viewModel)
                                }

                                // Krediler Grubu
                                if !viewModel.krediHesaplari.isEmpty {
                                    hesapGrubu(titleKey: "accounts.group.loans", hesaplar: viewModel.krediHesaplari, viewModel: viewModel)
                                }
                            }
                            .padding(.horizontal) // Kenarlara boşluk
                            .padding(.top, 10)
                            .padding(.bottom, 90)
                        }
                        // ÖNCEKİ GÖRÜNÜM: Arka planı tekrar beyaz (.systemBackground) yapıyoruz.
                        .background(Color(.systemBackground))
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
            // Bu kısım aynı kalabilir
            let dilKodu = appSettings.languageCode
            guard let path = Bundle.main.path(forResource: dilKodu, ofType: "lproj"),
                  let languageBundle = Bundle(path: path) else {
                return Text(hesap.isim)
            }
            let key: String
            switch hesap.detay {
            case .cuzdan: key = "alert.delete_wallet.message_format"
            case .krediKarti: key = "alert.delete_credit_card.message_format"
            case .kredi: key = "alert.delete_loan.message_format"
            }
            let formatString = languageBundle.localizedString(forKey: key, value: "", table: nil)
            return Text(String(format: formatString, hesap.isim))
        }
    }

    // Her bir hesap grubunu (başlık + kartlar) oluşturan yardımcı fonksiyon
    @ViewBuilder
    private func hesapGrubu(titleKey: LocalizedStringKey, hesaplar: [GosterilecekHesap], viewModel: HesaplarViewModel) -> some View {
        VStack(alignment: .leading, spacing: 16) { // Kartlar arasına boşluk
            Text(titleKey)
                .font(.title2.bold()) // Başlığı daha belirgin yapıyoruz
                .foregroundColor(.primary)
                .padding(.leading, 8) // Başlığa hafif bir iç boşluk

            ForEach(hesaplar) { bilgi in
                NavigationLink(destination: navigationDestination(for: bilgi.hesap)) {
                    hesapKarti(for: bilgi, viewModel: viewModel)
                }
                .buttonStyle(PlainButtonStyle()) // Tıklama efektini ve oku kaldırır
            }
        }
    }

    // Bu yardımcı fonksiyonlarda değişiklik yok
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

