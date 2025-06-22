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

#Preview {
    do {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Islem.self, Kategori.self, Hesap.self, configurations: config)
        return RaporlarView(modelContext: container.mainContext)
            .modelContainer(container)
            .environmentObject(AppSettings())
    } catch {
        fatalError("Preview için ModelContainer oluşturulamadı: \(error)")
    }
}
