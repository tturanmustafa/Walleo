import SwiftUI
import SwiftData

struct ButceDetayView: View {
    
    // MARK: - Environment ve State Değişkenleri
    
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appSettings: AppSettings
    @Environment(\.dismiss) private var dismiss
    
    // Bu görünümün tüm mantığını ve verisini yöneten ViewModel
    @State private var viewModel: ButceDetayViewModel
    
    // Sheet ve Alert'leri kontrol eden durumlar
    @State private var duzenlenecekIslem: Islem?
    @State private var silinecekIslem: Islem?
    @State private var butceDuzenleGoster = false
    @State private var butceSilUyarisiGoster = false
    
    // Bütçenin geçmiş bir döneme ait olup olmadığını kontrol eder
    private var isGecmisDonem: Bool {
        let bugun = Calendar.current.startOfDay(for: Date())
        let butceDonemi = viewModel.butce.periyot
        
        // Mevcut ayın başlangıcını güvenli bir şekilde bul
        guard let mevcutAyBasi = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: bugun)) else {
            return false // Hata durumunda düzenlemeye izin ver (güvenli varsayım)
        }
        
        // Bütçenin dönemi, mevcut ayın başlangıcından önceyse, geçmiş dönemdir.
        return butceDonemi < mevcutAyBasi
    }

    // MARK: - Init
    
    init(butce: Butce) {
        _viewModel = State(initialValue: ButceDetayViewModel(butce: butce))
    }

    // MARK: - Ana Body
    
    var body: some View {
        List {
            anaKartSection
            donemBilgileriSection
            islemlerSection
        }
        .navigationTitle(viewModel.butce.isim)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { /* Toolbar artık boş, çünkü tüm aksiyonlar kartın içindeki menüde. */ }
        // Görünüm ekrana geldiğinde ve veri değiştiğinde ViewModel'ı tetikle
        .onAppear {
            viewModel.fetchData(context: modelContext)
        }
        .onReceive(NotificationCenter.default.publisher(for: .transactionsDidChange)) { _ in
            viewModel.fetchData(context: modelContext)
        }
        // İşlem düzenleme ekranını açar
        .sheet(item: $duzenlenecekIslem) { islem in
            IslemEkleView(duzenlenecekIslem: islem)
                .environmentObject(appSettings)
        }
        // Bütçe düzenleme ekranını açar
        .sheet(isPresented: $butceDuzenleGoster) {
            ButceEkleDuzenleView(duzenlenecekButce: viewModel.butce)
                .environmentObject(appSettings)
        }
        // Bütçe silme uyarısını gösterir
        .alert(
            LocalizedStringKey("alert.delete_confirmation.title"),
            isPresented: $butceSilUyarisiGoster
        ) {
            Button("common.delete", role: .destructive, action: deleteBudget)
            Button("common.cancel", role: .cancel) { }
        } message: {
            // --- DÜZELTİLMİŞ YAPI ---
            // Önce formatlanacak ana metni lokalizasyon dosyasından alıyoruz.
            let formatString = NSLocalizedString("alert.delete_budget.message_format", comment: "")
            // Sonra String(format:) ile bütçe ismini içine yerleştiriyoruz.
            Text(String(format: formatString, viewModel.butce.isim))
            // --- DÜZELTME SONU ---
        }
        // İşlem silme uyarısını gösterir
        .confirmationDialog(
            "İşlemi Sil",
            isPresented: .constant(silinecekIslem != nil),
            presenting: silinecekIslem
        ) { islem in
            Button("alert.delete_this_only", role: .destructive) {
                deleteTransaction(islem)
            }
            if islem.tekrar != .tekSeferlik {
                Button("alert.delete_series", role: .destructive) {
                    deleteTransactionSeries(islem)
                }
            }
            Button("common.cancel", role: .cancel) { silinecekIslem = nil }
        } message: { islem in
             Text(islem.tekrar != .tekSeferlik ? LocalizedStringKey("alert.recurring_transaction") : LocalizedStringKey("alert.delete_transaction.message"))
        }
    }
    
    // MARK: - Alt Bileşenler (@ViewBuilder)
    
    /// Ana bütçe kartını gösteren bölüm.
    @ViewBuilder
    private var anaKartSection: some View {
        // ViewModel veriyi çekene kadar kartı gösterme
        if let gosterilecekButce = viewModel.gosterilecekButce {
            Section {
                ButceKartView(
                    gosterilecekButce: gosterilecekButce,
                    isDuzenlenebilir: !isGecmisDonem, // "Düzenle" menü ögesini bu değişkene göre kontrol eder
                    onEdit: { butceDuzenleGoster = true },
                    onDelete: { butceSilUyarisiGoster = true }
                )
                .environmentObject(appSettings)
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
    }

    /// Dönem ve devir bilgilerini gösteren bölüm.
    @ViewBuilder
    private var donemBilgileriSection: some View {
        Section(LocalizedStringKey("budget.detail.period_info")) {
            HStack {
                Text(LocalizedStringKey("budget.detail.budget_period"))
                    .foregroundColor(.secondary)
                Spacer()
                Text(monthYearString(from: viewModel.butce.periyot, localeIdentifier: appSettings.languageCode))
                    .fontWeight(.semibold)
            }
            
            if viewModel.butce.devredenGelenTutar > 0 {
                DisclosureGroup {
                    // Devir geçmişindeki her bir ay için bir satır oluştur
                    ForEach(viewModel.butce.devirGecmisiSozlugu.sorted(by: { $0.key < $1.key }), id: \.key) { (ay, tutar) in
                        HStack {
                            Text(ay)
                            Spacer()
                            Text(formatCurrency(amount: tutar, currencyCode: appSettings.currencyCode, localeIdentifier: appSettings.languageCode))
                        }
                        .font(.caption)
                    }
                } label: {
                    // Ana satır, toplam devreden tutarı gösterir
                    HStack {
                        Text(LocalizedStringKey("budget.detail.rollover_from_last_month"))
                        Spacer()
                        Text(formatCurrency(amount: viewModel.butce.devredenGelenTutar, currencyCode: appSettings.currencyCode, localeIdentifier: appSettings.languageCode))
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                    }
                    .contentShape(Rectangle()) // Tüm satırın tıklanabilir olmasını sağlar
                }
            }
        }
    }
    
    /// Bütçeye ait işlemleri listeleyen bölüm.
    @ViewBuilder
    private var islemlerSection: some View {
        Section(LocalizedStringKey("budget.detail.transactions_for_period")) {
            if viewModel.donemIslemleri.isEmpty {
                ContentUnavailableView(
                    LocalizedStringKey("budget_details.no_transactions"),
                    systemImage: "doc.text.magnifyingglass"
                )
            } else {
                ForEach(viewModel.donemIslemleri) { islem in
                    IslemSatirView(
                        islem: islem,
                        onEdit: { duzenlenecekIslem = islem },
                        onDelete: { silinecekIslem = islem }
                    )
                }
            }
        }
    }
    
    // MARK: - Yardımcı Fonksiyonlar
    
    /// Bütçeyi siler.
    private func deleteBudget() {
        viewModel.deleteButce(context: modelContext)
        dismiss()
    }
    
    /// Tek bir işlemi siler.
    private func deleteTransaction(_ islem: Islem) {
        TransactionService.shared.deleteTransaction(islem, in: modelContext)
        silinecekIslem = nil // Dialog'u kapat
    }
    
    /// Tekrarlanan bir işlem serisini siler.
    private func deleteTransactionSeries(_ islem: Islem) {
        Task {
            await TransactionService.shared.deleteSeriesInBackground(tekrarID: islem.tekrarID, from: modelContext.container)
            silinecekIslem = nil // Dialog'u kapat
        }
    }
}
