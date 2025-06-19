import SwiftUI
import SwiftData

struct RaporlarView: View {
    @State private var viewModel: RaporlarViewModel
    @Environment(\.modelContext) private var modelContext
    
    @State private var secilenRaporTuru: RaporTuru = .ozet
    
    enum RaporTuru: CaseIterable {
        case ozet, takvim, dagilim
        
        var localizedKey: LocalizedStringKey {
            switch self {
            case .ozet:
                return "reports.type.summary"
            case .takvim:
                return "tab.calendar"
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
                
                // Bu navigator artık tüm sekmeleri kontrol edecek.
                MonthNavigatorView(currentDate: $viewModel.currentDate)
                    .padding(.bottom, 10)
                
                Picker("Rapor Türü", selection: $secilenRaporTuru.animation()) {
                    ForEach(RaporTuru.allCases, id: \.self) { tur in
                        Text(tur.localizedKey).tag(tur)
                    }
                }
                .pickerStyle(.segmented)
                .padding([.horizontal, .bottom])
                
                switch secilenRaporTuru {
                case .ozet:
                    OzetView(viewModel: viewModel)
                case .takvim:
                    // Takvim'e artık ViewModel'daki ana tarihi bir binding olarak veriyoruz.
                    TakvimView(modelContext: modelContext, currentDate: $viewModel.currentDate)
                case .dagilim:
                    DagilimView(viewModel: viewModel)
                }
            }
            .task {
                await viewModel.fetchData()
            }
        }
    }
}
