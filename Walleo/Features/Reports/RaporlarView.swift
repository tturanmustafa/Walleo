import SwiftUI
import SwiftData

@MainActor
protocol RaporViewModelProtocol: Observable {
    var ozetVerisi: OzetVerisi { get }
    var karsilastirmaVerisi: KarsilastirmaVerisi { get }
    var topGiderKategorileri: [KategoriOzetSatiri] { get }
    var giderDagilimVerisi: [KategoriOzetSatiri] { get }
    var gelirDagilimVerisi: [KategoriOzetSatiri] { get }
    var isLoading: Bool { get }
}

struct RaporlarView: View {
    @Environment(\.modelContext) private var modelContext
    
    @State private var secilenRaporPeriyodu: RaporPeriyodu = .aylik
    
    enum RaporPeriyodu {
        case haftalik, aylik
        var localizedKey: LocalizedStringKey {
            switch self {
            case .haftalik: "reports.period.weekly"
            case .aylik: "reports.period.monthly"
            }
        }
    }
    
    var body: some View {
        // NavigationStack buradan kaldırıldı.
        VStack(spacing: 0) {
            Picker("Rapor Periyodu", selection: $secilenRaporPeriyodu.animation()) {
                Text(RaporPeriyodu.haftalik.localizedKey).tag(RaporPeriyodu.haftalik)
                Text(RaporPeriyodu.aylik.localizedKey).tag(RaporPeriyodu.aylik)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 10)

            switch secilenRaporPeriyodu {
            case .haftalik:
                HaftalikRaporlarContentView(modelContext: modelContext)
            case .aylik:
                AylikRaporlarContentView(modelContext: modelContext)
            }
        }
        .navigationTitle("tab.reports") // Bu modifier'lar hala çalışacak.
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Haftalık Raporlar İçerik Görünümü
private struct HaftalikRaporlarContentView: View {
    @State private var viewModel: HaftalikRaporlarViewModel
    @State private var secilenRaporTuru: RaporTuru = .ozet
    
    enum RaporTuru: CaseIterable {
        case ozet, dagilim
        var localizedKey: LocalizedStringKey {
            switch self {
            case .ozet: "reports.type.summary"
            case .dagilim: "reports.type.distribution"
            }
        }
    }
    
    init(modelContext: ModelContext) {
        _viewModel = State(initialValue: HaftalikRaporlarViewModel(modelContext: modelContext))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            WeekNavigatorView(currentDate: $viewModel.currentDate)
                .padding(.top, 16)
            
            Picker("Rapor Türü", selection: $secilenRaporTuru.animation()) {
                ForEach(RaporTuru.allCases, id: \.self) { tur in Text(tur.localizedKey).tag(tur) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 20)
            .padding(.bottom, 8)

            VStack {
                switch secilenRaporTuru {
                case .ozet:
                    OzetView(viewModel: viewModel)
                case .dagilim:
                    DagilimView(viewModel: viewModel)
                }
                // NİHAİ DÜZELTME: Haftalık görünümde de Spacer ekleyerek tutarlılığı sağlıyoruz.
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .task {
            await viewModel.fetchData()
        }
    }
}


// MARK: - Aylık Raporlar İçerik Görünümü
private struct AylikRaporlarContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: RaporlarViewModel
    @State private var secilenRaporTuru: RaporTuru = .ozet

    enum RaporTuru: CaseIterable {
        case ozet, dagilim
        var localizedKey: LocalizedStringKey {
            switch self {
            case .ozet: "reports.type.summary"
            case .dagilim: "reports.type.distribution"
            }
        }
    }
    
    init(modelContext: ModelContext) {
        _viewModel = State(initialValue: RaporlarViewModel(modelContext: modelContext))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            MonthNavigatorView(currentDate: $viewModel.currentDate)
                .padding(.top, 16)
            
            Picker("Rapor Türü", selection: $secilenRaporTuru.animation(.easeInOut)) {
                ForEach(RaporTuru.allCases, id: \.self) { tur in Text(tur.localizedKey).tag(tur) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 20)
            .padding(.bottom, 8)
            
            VStack {
                switch secilenRaporTuru {
                case .ozet:
                    OzetView(viewModel: viewModel)
                case .dagilim:
                    DagilimView(viewModel: viewModel)
                }
                
                // NİHAİ DÜZELTME: Bu Spacer, Takvim gibi yüksekliği sabit olan görünümlerde bile
                // container'ın tüm alanı kaplamasını sağlar. Bu da üstteki menülerin "zıplamasını" engeller.
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .task {
            await viewModel.fetchData()
        }
    }
}
