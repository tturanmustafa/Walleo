// Dosya Adı: HesaplarView.swift

import SwiftUI
import SwiftData

struct HesaplarView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appSettings: AppSettings
    
    @State private var viewModel: HesaplarViewModel
    
    // Açılacak olan Add/Edit pencerelerini yönetmek için kullanılan enum
    enum SheetTuru: Identifiable {
        case cuzdanEkle, krediKartiEkle, krediEkle
        case cuzdanDuzenle(Hesap), krediKartiDuzenle(Hesap), krediDuzenle(Hesap)
        
        var id: String { // Identifiable olması için her case'e özel bir kimlik
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

    init() {
        // ModelContainer'a tüm modellerimizi tanıtıyoruz.
        let container = try! ModelContainer(for: Hesap.self, Islem.self, Kategori.self)
        _viewModel = State(initialValue: HesaplarViewModel(modelContext: container.mainContext))
    }

    var body: some View {
        NavigationStack {
            hesapListesi
                .overlay {
                    if viewModel.gosterilecekHesaplar.isEmpty {
                        ContentUnavailableView("Henüz Hesap Yok", systemImage: "wallet.pass", description: Text("Başlamak için '+' ikonuna dokunarak yeni bir hesap ekleyin."))
                    }
                }
                .navigationTitle(LocalizedStringKey("accounts.title"))
                .toolbar { toolbarIcerigi }
                .sheet(item: $gosterilecekSheet, onDismiss: viewModel.hesaplamalariTetikle) { sheet in
                    sheet.view
                }
                .task {
                    viewModel.modelContext = self.modelContext
                    await viewModel.hesaplamalariYap()
                }
        }
    }
    
    // MARK: - View Parçaları
    
    private var hesapListesi: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(viewModel.gosterilecekHesaplar) { bilgi in
                    // Sadece kredi ise NavigationLink içine alınıyor.
                    if case .kredi = bilgi.hesap.detay {
                        NavigationLink(destination: detayEkraniniGetir(hesap: bilgi.hesap)) {
                            hesapKarti(for: bilgi)
                        }
                        .buttonStyle(.plain)
                    } else {
                        // Diğer hesap türleri (Cüzdan, Kredi Kartı) tıklanamaz.
                        hesapKarti(for: bilgi)
                    }
                }
            }
            .padding()
        }
    }
    
    // Kod tekrarını önlemek için ortak kart oluşturma fonksiyonu
    @ViewBuilder
    private func hesapKarti(for bilgi: GosterilecekHesap) -> some View {
        HesapKartView(
            gosterilecekHesap: bilgi,
            onEdit: { presentEditSheet(for: bilgi.hesap) },
            onDelete: { viewModel.hesabiSil(hesap: bilgi.hesap) }
        )
        .environmentObject(appSettings)
    }
    
    private var toolbarIcerigi: some ToolbarContent {
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
            } label: {
                Image(systemName: "plus")
            }
        }
    }
    
    // MARK: - Yardımcı Fonksiyonlar

    private func presentEditSheet(for hesap: Hesap) {
        switch hesap.detay {
        case .cuzdan:
            gosterilecekSheet = .cuzdanDuzenle(hesap)
        case .krediKarti:
            gosterilecekSheet = .krediKartiDuzenle(hesap)
        case .kredi:
            gosterilecekSheet = .krediDuzenle(hesap)
        }
    }

    @ViewBuilder
    private func detayEkraniniGetir(hesap: Hesap) -> some View {
        switch hesap.detay {
        case .kredi:
            KrediDetayView(hesap: hesap)
        case .krediKarti:
            KrediKartiDetayView(kartHesabi: hesap)
        default:
            // İleride Cüzdan ve Kredi Kartı için de işlem listesi gösteren
            // ortak bir detay ekranı yapılabilir.
            Text("\(hesap.isim) Detay Ekranı")
        }
    }
}


// MARK: - SheetTuru Enum'ı için View Oluşturucu
extension HesaplarView.SheetTuru {
    @ViewBuilder
    var view: some View {
        switch self {
        case .cuzdanEkle:
            // Not: BasitHesapEkleView dosyasını daha önce CuzdanEkleView olarak
            // yeniden adlandırmayı konuşmuştuk, projedeki ismine göre güncelleyebilirsiniz.
            BasitHesapEkleView()
        case .krediKartiEkle:
            KrediKartiEkleView()
        case .krediEkle:
            KrediEkleView()
        case .cuzdanDuzenle(let hesap):
            BasitHesapEkleView(duzenlenecekHesap: hesap)
        case .krediKartiDuzenle(let hesap):
            KrediKartiEkleView(duzenlenecekHesap: hesap)
        case .krediDuzenle(let hesap):
            KrediEkleView(duzenlenecekHesap: hesap)
        }
    }
}
