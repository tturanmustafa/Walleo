import SwiftUI
import SwiftData
import Charts

// Bu yardımcı View'da değişiklik yok, aynı kalıyor.
struct IslemTuruButonu: View {
    let tur: IslemTuru
    @Binding var secilenTur: IslemTuru
    let animation: Namespace.ID

    var body: some View {
        Text(LocalizedStringKey(tur.rawValue))
            .font(.subheadline)
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .padding(.horizontal, 15)
            .foregroundColor(secilenTur == tur ? .primary : .secondary)
            .background {
                if secilenTur == tur {
                    Capsule()
                        .fill(Color(.systemBackground))
                        .matchedGeometryEffect(id: "ACTIVETAB", in: animation)
                        .overlay(
                            Capsule().stroke(tur == .gelir ? .green : .red, lineWidth: 1.5)
                        )
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.3)) {
                    secilenTur = tur
                }
            }
    }
}

struct DashboardView: View {
    @EnvironmentObject var appSettings: AppSettings
    @Environment(\.colorScheme) var systemColorScheme
    @Environment(\.modelContext) private var modelContext
    
    @State private var viewModel: DashboardViewModel
    
    @Query(filter: #Predicate<Bildirim> { !$0.okunduMu }) private var unreadNotifications: [Bildirim]
    
    @State private var duzenlenecekIslem: Islem?
    @State private var silinecekTekrarliIslem: Islem?
    @State private var silinecekTekilIslem: Islem?
    
    @State private var isShowingSettings = false
    @State private var isShowingNotifications = false
    @State private var silinecekTaksitliIslem: Islem?

    @Namespace private var animation

    private var sheetColorScheme: ColorScheme {
        switch appSettings.colorSchemeValue {
        case 1: return .light
        case 2: return .dark
        default: return systemColorScheme
        }
    }
    
    init(modelContext: ModelContext) {
        _viewModel = State(initialValue: DashboardViewModel(modelContext: modelContext))
    }

    var body: some View {
        ZStack {
            NavigationStack {
                VStack(spacing: 0) {
                    // YENİ: Header bölümünü ayrı bir computed property yap
                    headerSection
                    
                    // YENİ: LazyVStack kullanarak performans artışı
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 12) {
                            // YENİ: Chart'ı sadece veri varken göster
                            if !viewModel.pieChartVerisi.isEmpty {
                                ChartPanelView(
                                    pieChartVerisi: viewModel.pieChartVerisi,
                                    kategoriDetaylari: viewModel.kategoriDetaylari,
                                    toplamTutar: viewModel.toplamTutar
                                )
                                // YENİ: id ile gereksiz re-render'ları önle
                                .id("chart_\(viewModel.currentDate.timeIntervalSince1970)_\(viewModel.secilenTur.rawValue)")
                            }
                            
                            if !viewModel.pieChartVerisi.isEmpty && !viewModel.filtrelenmisIslemler.isEmpty {
                                dividerLine
                            }
                            
                            // YENİ: Son işlemler bölümünü optimize et
                            recentTransactionsSection
                        }
                        // YENİ: Animasyonu sadece içerik değişiminde uygula
                        .animation(.easeInOut(duration: 0.2), value: viewModel.filtrelenmisIslemler.count)
                        .padding(.vertical)
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        notificationButton
                    }
                    
                    ToolbarItem(placement: .topBarTrailing) {
                        settingsButton
                    }
                }
                .navigationTitle(LocalizedStringKey("tab.dashboard"))
                .navigationBarTitleDisplayMode(.inline)
            }
            .disabled(viewModel.isDeleting)
            .sheet(isPresented: $isShowingSettings) {
                NavigationStack {
                    AyarlarView()
                }
                .preferredColorScheme(sheetColorScheme)
            }
            .sheet(isPresented: $isShowingNotifications) {
                BildirimlerView()
            }
            .sheet(item: $duzenlenecekIslem, onDismiss: { viewModel.fetchData() }) { islem in
                IslemEkleView(duzenlenecekIslem: islem)
                    .environmentObject(appSettings)
            }
            .recurringTransactionAlert(
                for: $silinecekTekrarliIslem,
                onDeleteSingle: { islem in viewModel.deleteIslem(islem) },
                onDeleteSeries: { islem in viewModel.deleteSeri(for: islem) }
            )
            .alert(
                LocalizedStringKey("alert.installment.delete_title"),
                isPresented: Binding(isPresented: $silinecekTaksitliIslem),
                presenting: silinecekTaksitliIslem
            ) { islem in
                Button(role: .destructive) {
                    TransactionService.shared.deleteTaksitliIslem(islem, in: modelContext)
                } label: {
                    Text("common.delete")
                }
            } message: { islem in
                Text(String(format: NSLocalizedString("transaction.installment.delete_warning", comment: ""), islem.toplamTaksitSayisi))
            }
            .alert(
                LocalizedStringKey("alert.delete_confirmation.title"),
                isPresented: Binding(isPresented: $silinecekTekilIslem),
                presenting: silinecekTekilIslem
            ) { islem in
                Button(role: .destructive) {
                    viewModel.deleteIslem(islem)
                } label: { Text("common.delete") }
            } message: { islem in
                Text("alert.delete_transaction.message")
            }
            .onAppear {
                viewModel.fetchData()
            }
            // YENİ: onChange'i optimize et
            .onChange(of: viewModel.secilenTur) { _, _ in
                // ViewModel zaten kendi içinde kontrol ediyor
            }
            // YENİ: Sheet kapandığında veriyi güncelle
            .onChange(of: duzenlenecekIslem) { oldValue, newValue in
                if oldValue != nil && newValue == nil {
                    // Sheet kapandı, veriyi güncelle
                    viewModel.invalidateCache()
                    viewModel.fetchData()
                }
            }
            
            // YENİ: Yükleme göstergesi
            if viewModel.isDeleting {
                ProgressView("Siliniyor...")
                    .padding(25)
                    .background(Material.thick)
                    .cornerRadius(10)
                    .shadow(radius: 5)
            }
        }
    }
    
    // YENİ: Header bölümünü ayır
    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: 0) {
            MonthNavigatorView(currentDate: $viewModel.currentDate)
                .padding(.bottom, 10)
            
            transactionTypePicker
                .padding(.bottom, 10)
            
            totalAmountView
                .transition(.opacity.animation(.easeInOut))
                .id("totalAmount_\(viewModel.secilenTur.rawValue)")
                .padding(.bottom, 12)
            
            dividerLine
        }
    }
    
    // YENİ: Recent transactions'ı optimize et
    @ViewBuilder
    private var recentTransactionsSection: some View {
        if !viewModel.filtrelenmisIslemler.isEmpty {
            RecentTransactionsView(
                modelContext: viewModel.modelContext,
                islemler: Array(viewModel.filtrelenmisIslemler.prefix(5)), // Sadece ilk 5'i göster
                currentDate: viewModel.currentDate,
                duzenlenecekIslem: $duzenlenecekIslem,
                onSilmeyiBaslat: { islem in
                    self.silmeyiBaslat(islem)
                }
            )
            .environmentObject(appSettings)
            // YENİ: Sabit id ile gereksiz re-render'ları önle
            .id("recent_transactions")
        }
    }
    
    // YENİ: Toolbar butonlarını ayır
    @ViewBuilder
    private var notificationButton: some View {
        Button(action: { isShowingNotifications = true }) {
            ZStack {
                Image(systemName: "bell.fill")
                    .font(.title3)
                    .foregroundColor(.secondary)
                
                if !unreadNotifications.isEmpty {
                    Text("\(unreadNotifications.count)")
                        .font(.caption2.bold())
                        .foregroundColor(.white)
                        .padding(5)
                        .background(Circle().fill(Color.red))
                        .offset(x: 12, y: -10)
                        .transition(.scale)
                }
            }
        }
    }
    
    @ViewBuilder
    private var settingsButton: some View {
        Button(action: { isShowingSettings = true }) {
            Image(systemName: "gearshape.fill")
                .font(.title3)
                .foregroundColor(.secondary)
        }
    }
    
    var transactionTypePicker: some View {
        HStack(spacing: 0) {
            ForEach(IslemTuru.allCases, id: \.self) { tur in
                IslemTuruButonu(tur: tur, secilenTur: $viewModel.secilenTur, animation: animation)
            }
        }
        .background(Color(.systemGray6))
        .clipShape(Capsule())
        .padding(.horizontal)
    }
    
    var totalAmountView: some View {
        Text(formatCurrency(
            amount: viewModel.toplamTutar,
            currencyCode: appSettings.currencyCode,
            localeIdentifier: appSettings.languageCode
        ))
        .font(.title.bold())
        .foregroundColor(viewModel.secilenTur == .gelir ? .green : .red)
        .padding(.vertical, 10)
    }
    
    var dividerLine: some View {
        Rectangle().fill(.gray.opacity(0.15)).frame(height: 1).padding(.horizontal)
    }
    
    // GÜNCELLENMİŞ FONKSİYON
    private func silmeyiBaslat(_ islem: Islem) {
        // Taksitli işlem kontrolü
        if islem.taksitliMi {
            silinecekTaksitliIslem = islem
        } else if islem.tekrar != .tekSeferlik && islem.tekrarID != UUID() {
            silinecekTekrarliIslem = islem
        } else {
            silinecekTekilIslem = islem
        }
    }
}
