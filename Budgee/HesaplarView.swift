// Dosya Adı: HesaplarView.swift (MİMARİSİ DÜZELTİLMİŞ NİHAİ HALİ)

import SwiftUI
import SwiftData

struct HesaplarView: View {
    // 1. ADIM: Artık context'i tüm uygulama gibi environment'tan alıyoruz.
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appSettings: AppSettings
    
    // 2. ADIM: ViewModel'ı, context'i aldıktan sonra oluşturabilmek için opsiyonel yapıyoruz.
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

    // 3. ADIM: HATALI INIT METODU TAMAMEN KALDIRILDI.
    // Artık bu view kendi başına veritabanı bağlantısı oluşturmuyor.

    var body: some View {
        NavigationStack {
            // 4. ADIM: ViewModel oluşturulana kadar bir yükleme ekranı gösteriyoruz.
            if let viewModel = viewModel {
                hesapListesi(viewModel: viewModel)
                    .overlay {
                        if viewModel.gosterilecekHesaplar.isEmpty {
                            ContentUnavailableView(LocalizedStringKey("accounts.empty.title"), systemImage: "wallet.pass", description: Text(LocalizedStringKey("accounts.empty.description")))
                        }
                    }
                    .navigationTitle(LocalizedStringKey("accounts.title"))
                    .toolbar { toolbarIcerigi(viewModel: viewModel) }
                    .sheet(item: $gosterilecekSheet, onDismiss: viewModel.hesaplamalariTetikle) { sheet in
                        sheet.view
                    }
            } else {
                ProgressView()
            }
        }
        .task {
            // 5. ADIM: View ekrana geldiğinde, environment'tan alınan doğru context ile ViewModel'ı oluşturuyoruz.
            if viewModel == nil {
                viewModel = HesaplarViewModel(modelContext: self.modelContext)
                await viewModel?.hesaplamalariYap()
            }
        }
    }
    
    // View'ın parçaları artık viewModel'ı parametre olarak alıyor.
    private func hesapListesi(viewModel: HesaplarViewModel) -> some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(viewModel.gosterilecekHesaplar) { bilgi in
                    if case .kredi = bilgi.hesap.detay {
                        NavigationLink(destination: detayEkraniniGetir(hesap: bilgi.hesap)) {
                            hesapKarti(for: bilgi, viewModel: viewModel)
                        }
                        .buttonStyle(.plain)
                    } else {
                        hesapKarti(for: bilgi, viewModel: viewModel)
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
            onDelete: { viewModel.hesabiSil(hesap: bilgi.hesap) }
        )
        .environmentObject(appSettings)
    }
    
    private func toolbarIcerigi(viewModel: HesaplarViewModel) -> some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
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
            } label: { Image(systemName: "plus") }
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
        default: Text("\(hesap.isim) Detay Ekranı")
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
