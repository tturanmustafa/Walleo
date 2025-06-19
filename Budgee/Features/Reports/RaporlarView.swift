import SwiftUI
import SwiftData

struct RaporlarView: View {
    @State private var viewModel: RaporlarViewModel
    @State private var secilenRaporTuru: RaporTuru = .ozet
    
    enum RaporTuru: CaseIterable {
        case ozet, dagilim
        
        var localizedKey: LocalizedStringKey {
            switch self {
            case .ozet:
                return "reports.type.summary"
            case .dagilim:
                return "reports.type.distribution"
            }
        }
    }
    
    init(modelContext: ModelContext) {
        _viewModel = State(initialValue: RaporlarViewModel(modelContext: modelContext))
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                
                // YENİ: Ay/Yıl Navigasyon barı eklendi.
                MonthNavigatorView(currentDate: $viewModel.currentDate)
                    .padding(.bottom, 10)
                
                Picker("Rapor Türü", selection: $secilenRaporTuru) {
                    ForEach(RaporTuru.allCases, id: \.self) { tur in
                        Text(tur.localizedKey).tag(tur)
                    }
                }
                .pickerStyle(.segmented)
                .padding([.horizontal, .bottom])
                
                // Seçime göre ilgili View'ı göster.
                // Artık bu view'lar da seçilen aya göre dinamik olarak güncellenecek.
                switch secilenRaporTuru {
                case .ozet:
                    OzetView(viewModel: viewModel)
                case .dagilim:
                    DagilimView(viewModel: viewModel)
                }
            }
            .task {
                // Ekran ilk açıldığında veriyi çekmek için
                await viewModel.fetchData()
            }
        }
    }
}
