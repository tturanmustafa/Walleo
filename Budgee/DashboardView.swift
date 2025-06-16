import SwiftUI
import SwiftData
import Charts

// ÖNCE YENİ, KÜÇÜK VIEW'IMIZI TANIMLIYORUZ
// Bu, derleme hatasını çözen en önemli adımdı.
struct IslemTuruButonu: View {
    let tur: IslemTuru
    @Binding var secilenTur: IslemTuru
    let animation: Namespace.ID

    var body: some View {
        Text(tur.rawValue)
            .font(.subheadline)
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity)
            // İki padding komutunu zincirleyerek derleyiciye yardımcı oluyoruz.
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


struct DashboardView: View {
    @State private var viewModel: DashboardViewModel
    
    // Diğer state'ler
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
            // --- SABİT KALACAK ÜST KISIM ---
            monthNavigatorView
                .padding(.bottom, 10)
            
            transactionTypePicker
                .padding(.bottom, 10)
            
            totalAmountView
                .padding(.bottom, 12)
            
            dividerLine
            
            // --- KAYDIRILABİLİR ALT KISIM ---
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
        }
        .sheet(isPresented: $duzenlemeEkraniGosteriliyor, onDismiss: { viewModel.fetchData() }) {
            IslemEkleView(duzenlenecekIslem: duzenlenecekIslem)
        }
        .confirmationDialog("Bu tekrarlayan bir işlemdir.", isPresented: .constant(silinecekIslem != nil), titleVisibility: .visible) {
            Button("Sadece Bu İşlemi Sil", role: .destructive) {
                if let islem = silinecekIslem { viewModel.modelContext.delete(islem) }
                silinecekIslem = nil
            }
            Button("Tüm Seriyi Sil", role: .destructive) {
                if let islem = silinecekIslem { seriyiSil(islem: islem) }
                silinecekIslem = nil
            }
            Button("İptal", role: .cancel) { silinecekIslem = nil }
        }
        .onAppear {
            viewModel.fetchData()
        }
    }
    
    // Yardımcı view'lar ve fonksiyonlar...
    @ViewBuilder
    var monthNavigatorView: some View {
        HStack {
            Button(action: { viewModel.currentDate = Calendar.current.date(byAdding: .month, value: -1, to: viewModel.currentDate) ?? viewModel.currentDate }) { Image(systemName: "chevron.left") }
            Spacer()
            Text(monthYearString(from: viewModel.currentDate)).fontWeight(.semibold).foregroundColor(.primary).onTapGesture { ayYilSeciciGosteriliyor = true }
            Spacer()
            Button(action: { viewModel.currentDate = Calendar.current.date(byAdding: .month, value: 1, to: viewModel.currentDate) ?? viewModel.currentDate }) { Image(systemName: "chevron.right") }
        }
        .font(.title3).foregroundColor(.secondary).padding(.horizontal, 30).padding(.top)
    }
    
    var transactionTypePicker: some View {
        HStack(spacing: 0) {
            ForEach(IslemTuru.allCases, id: \.self) { tur in
                // Karmaşık kod yerine artık basitçe yeni view'imizi çağırıyoruz.
                IslemTuruButonu(tur: tur, secilenTur: $viewModel.secilenTur, animation: animation)
            }
        }
        .background(Color(.systemGray6))
        .clipShape(Capsule())
        .padding(.horizontal)
    }
    
    var totalAmountView: some View {
        formatCurrency(amount: viewModel.toplamTutar, font: .largeTitle, color: viewModel.secilenTur == .gelir ? .green : .red).padding(.vertical, 10)
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
