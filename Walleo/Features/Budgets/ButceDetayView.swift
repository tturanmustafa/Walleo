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
    @State private var butceDuzenleGoster = false
    @State private var butceSilUyarisiGoster = false
    
    // --- 🔥 YENİ & GÜNCELLENMİŞ STATE'LER 🔥 ---
    // Her silme türü için ayrı bir state tanımlayarak doğru uyarıyı tetikliyoruz.
    @State private var silinecekTekilIslem: Islem?
    @State private var silinecekTekrarliIslem: Islem?
    @State private var silinecekTaksitliIslem: Islem?
    @State private var isDeletingSeries = false // Seri silinirken ProgressView göstermek için
    
    // Bütçenin geçmiş bir döneme ait olup olmadığını kontrol eder (Bu kod aynı kalıyor)
    private var isGecmisDonem: Bool {
        let bugun = Calendar.current.startOfDay(for: Date())
        let butceDonemi = viewModel.butce.periyot
        
        guard let mevcutAyBasi = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: bugun)) else {
            return false
        }
        
        return butceDonemi < mevcutAyBasi
    }

    // MARK: - Init (Bu kod aynı kalıyor)
    
    init(butce: Butce) {
        _viewModel = State(initialValue: ButceDetayViewModel(butce: butce))
    }

    // MARK: - Ana Body
    
    var body: some View {
        // ZStack, seri silinirken ProgressView'i ekranın üzerinde göstermek için eklendi.
        ZStack {
            List {
                anaKartSection
                donemBilgileriSection
                islemlerSection
            }
            .disabled(isDeletingSeries) // Seri silinirken arayüzü pasif hale getir
            .navigationTitle(viewModel.butce.isim)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { /* Toolbar boş kalabilir, menü kartın içinde */ }
            .onAppear {
                viewModel.fetchData(context: modelContext)
            }
            .onReceive(NotificationCenter.default.publisher(for: .transactionsDidChange)) { _ in
                viewModel.fetchData(context: modelContext)
            }
            .sheet(item: $duzenlenecekIslem) { islem in
                IslemEkleView(duzenlenecekIslem: islem)
                    .environmentObject(appSettings)
            }
            .sheet(isPresented: $butceDuzenleGoster) {
                ButceEkleDuzenleView(duzenlenecekButce: viewModel.butce)
                    .environmentObject(appSettings)
            }
            .alert(
                LocalizedStringKey("alert.delete_confirmation.title"),
                isPresented: $butceSilUyarisiGoster
            ) {
                Button("common.delete", role: .destructive, action: deleteBudget)
                Button("common.cancel", role: .cancel) { }
            } message: {
                let formatString = NSLocalizedString("alert.delete_budget.message_format", comment: "")
                Text(String(format: formatString, viewModel.butce.isim))
            }
            
            // --- 🔥 YENİ EKLENEN/GÜNCELLENEN ALERT VE DIALOG'LAR 🔥 ---
            
            // 1. Tekrarlanan İşlem Silme Onayı
            .confirmationDialog(
                LocalizedStringKey("alert.recurring_transaction"),
                isPresented: Binding(isPresented: $silinecekTekrarliIslem),
                presenting: silinecekTekrarliIslem
            ) { islem in
                Button("alert.delete_this_only", role: .destructive) {
                    viewModel.deleteSingleTransaction(islem, context: modelContext)
                }
                Button("alert.delete_series", role: .destructive) {
                    Task {
                        isDeletingSeries = true
                        await viewModel.deleteTransactionSeries(islem)
                        isDeletingSeries = false
                    }
                }
                Button("common.cancel", role: .cancel) { }
            }
            
            // 2. Taksitli İşlem Silme Uyarısı
            .alert(
                LocalizedStringKey("alert.installment.delete_title"),
                isPresented: Binding(isPresented: $silinecekTaksitliIslem),
                presenting: silinecekTaksitliIslem
            ) { islem in
                Button(role: .destructive) {
                    viewModel.deleteInstallmentTransaction(islem, context: modelContext)
                } label: { Text("common.delete") }
            } message: { islem in
                Text(String(format: NSLocalizedString("transaction.installment.delete_warning", comment: ""), islem.toplamTaksitSayisi))
            }

            // 3. Tekil İşlem Silme Uyarısı
            .alert(
                LocalizedStringKey("alert.delete_confirmation.title"),
                isPresented: Binding(isPresented: $silinecekTekilIslem),
                presenting: silinecekTekilIslem
            ) { islem in
                Button(role: .destructive) {
                    viewModel.deleteSingleTransaction(islem, context: modelContext)
                } label: { Text("common.delete") }
            } message: { islem in
                Text("alert.delete_transaction.message")
            }
            
            // Yükleme göstergesi
            if isDeletingSeries {
                ProgressView("Seri Siliniyor...")
                    .padding(25)
                    .background(Material.thick)
                    .cornerRadius(10)
                    .shadow(radius: 5)
            }
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
                        onDelete: { silmeyiBaslat(islem) } // <-- ÖNEMLİ DEĞİŞİKLİK
                    )
                }
            }
        }
    }
    
    // MARK: - Yardımcı Fonksiyonlar
    private func deleteBudget() {
        viewModel.deleteButce(context: modelContext)
        dismiss()
    }

    private func silmeyiBaslat(_ islem: Islem) {
        if islem.taksitliMi {
            silinecekTaksitliIslem = islem
        } else if islem.tekrar != .tekSeferlik && islem.tekrarID != UUID() {
            silinecekTekrarliIslem = islem
        } else {
            silinecekTekilIslem = islem
        }
    }
}
