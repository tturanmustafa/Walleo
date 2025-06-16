import SwiftUI
import SwiftData
import Charts

struct IslemTuruButonu: View {
    let tur: IslemTuru
    @Binding var secilenTur: IslemTuru
    let animation: Namespace.ID

    var body: some View {
        // DEĞİŞİKLİK: rawValue'yu LocalizedStringKey içine alarak çeviriyi garanti ediyoruz.
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
                        .fill(.background)
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

// DashboardView'in geri kalanı aynı, sadece yukarıdaki IslemTuruButonu güncellendi.
// Tamlık açısından tüm dosyayı aşağıya ekliyorum.
struct DashboardView: View {
    @EnvironmentObject var appSettings: AppSettings
    @State private var viewModel: DashboardViewModel
    
    @State private var duzenlenecekIslem: Islem?
    @State private var duzenlemeEkraniGosteriliyor = false
    @State private var silinecekIslem: Islem?
    @State private var ayYilSeciciGosteriliyor = false
    @Namespace private var animation

    init(modelContext: ModelContext) {
        _viewModel = State(initialValue: DashboardViewModel(modelContext: modelContext))
    }

    var body: some View {
        VStack(spacing: 0) {
            monthNavigatorView
                .padding(.bottom, 10)
            
            transactionTypePicker
                .padding(.bottom, 10)
            
            totalAmountView
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
                    
                    RecentTransactionsView(
                        modelContext: viewModel.modelContext,
                        islemler: viewModel.filtrelenmisIslemler,
                        duzenlenecekIslem: $duzenlenecekIslem,
                        duzenlemeEkraniGosteriliyor: $duzenlemeEkraniGosteriliyor,
                        onSilmeyiBaslat: { islem in
                            self.silmeyiBaslat(islem)
                        }
                    )
                }
                .padding(.vertical)
            }
        }
        .sheet(isPresented: $ayYilSeciciGosteriliyor) {
            AyYilSeciciView(currentDate: viewModel.currentDate) { yeniTarih in viewModel.currentDate = yeniTarih }
                .presentationDetents([.height(300)])
                .environmentObject(appSettings)
        }
        .sheet(isPresented: $duzenlemeEkraniGosteriliyor, onDismiss: { viewModel.fetchData() }) {
            IslemEkleView(duzenlenecekIslem: duzenlenecekIslem)
        }
        .confirmationDialog("alert.recurring_transaction", isPresented: .constant(silinecekIslem != nil), titleVisibility: .visible) {
            Button("alert.delete_this_only", role: .destructive) {
                if let islem = silinecekIslem { viewModel.modelContext.delete(islem) }
                silinecekIslem = nil
            }
            Button("alert.delete_series", role: .destructive) {
                if let islem = silinecekIslem { seriyiSil(islem: islem) }
                silinecekIslem = nil
            }
            Button("common.cancel", role: .cancel) { silinecekIslem = nil }
        }
        .onAppear {
            viewModel.fetchData()
        }
    }
    
    @ViewBuilder
    var monthNavigatorView: some View {
        HStack {
            Button(action: { viewModel.currentDate = Calendar.current.date(byAdding: .month, value: -1, to: viewModel.currentDate) ?? viewModel.currentDate }) { Image(systemName: "chevron.left") }
            Spacer()
            Text(monthYearString(from: viewModel.currentDate, localeIdentifier: appSettings.languageCode))
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .onTapGesture { ayYilSeciciGosteriliyor = true }
            Spacer()
            Button(action: { viewModel.currentDate = Calendar.current.date(byAdding: .month, value: 1, to: viewModel.currentDate) ?? viewModel.currentDate }) { Image(systemName: "chevron.right") }
        }
        .font(.title3).foregroundColor(.secondary).padding(.horizontal, 30).padding(.top)
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
        formatCurrency(amount: viewModel.toplamTutar, font: .largeTitle, color: viewModel.secilenTur == .gelir ? .green : .red)
    }
    
    var dividerLine: some View {
        Rectangle().fill(.gray.opacity(0.15)).frame(height: 1).padding(.horizontal)
    }
    
    private func silmeyiBaslat(_ islem: Islem) {
        if islem.tekrar != .tekSeferlik && islem.tekrarID != UUID() {
            silinecekIslem = islem
        } else {
            viewModel.modelContext.delete(islem)
        }
    }

    private func seriyiSil(islem: Islem) {
        let tekrarID = islem.tekrarID
        try? viewModel.modelContext.delete(model: Islem.self, where: #Predicate { $0.tekrarID == tekrarID })
    }
}
