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
    
    @Namespace private var animation

    private var sheetColorScheme: ColorScheme {
        switch appSettings.colorSchemeValue {
        case 1: return .light // 'return' eklendi
        case 2: return .dark  // 'return' eklendi
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
                    MonthNavigatorView(currentDate: $viewModel.currentDate)
                        .padding(.bottom, 10)
                    
                    transactionTypePicker
                        .padding(.bottom, 10)
                    
                    totalAmountView
                        .transition(.opacity.animation(.easeInOut))
                        .id("totalAmount_\(viewModel.secilenTur.rawValue)")
                        .padding(.bottom, 12)
                    
                    dividerLine
                    
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 12) {
                            ChartPanelView(
                                pieChartVerisi: viewModel.pieChartVerisi,
                                kategoriDetaylari: viewModel.kategoriDetaylari,
                                toplamTutar: viewModel.toplamTutar
                            )
                            
                            if !viewModel.pieChartVerisi.isEmpty && !viewModel.filtrelenmisIslemler.isEmpty { dividerLine }
                            
                            // GÜNCELLEME: 'currentDate' parametresi eklendi.
                            RecentTransactionsView(
                                modelContext: viewModel.modelContext,
                                islemler: viewModel.filtrelenmisIslemler,
                                duzenlenecekIslem: $duzenlenecekIslem,
                                onSilmeyiBaslat: { islem in
                                    self.silmeyiBaslat(islem)
                                }
                            )
                            .environmentObject(appSettings)
                        }
                        .animation(.easeInOut(duration: 0.2), value: viewModel.filtrelenmisIslemler)
                        .padding(.vertical)
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
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
                    
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: { isShowingSettings = true }) {
                            Image(systemName: "gearshape.fill")
                                .font(.title3)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .navigationTitle(LocalizedStringKey("tab.dashboard"))
                .navigationBarTitleDisplayMode(.inline)
            }
            .disabled(viewModel.isDeleting) // GÜNCELLENDİ: Silinirken arayüzü pasif yap
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
            .onAppear { viewModel.fetchData() }
            .onChange(of: viewModel.secilenTur) { viewModel.fetchData() }
            
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
        if islem.tekrar != .tekSeferlik && islem.tekrarID != UUID() {
            silinecekTekrarliIslem = islem
        } else {
            silinecekTekilIslem = islem
        }
    }
}
