import SwiftUI
import SwiftData

struct TumIslemlerView: View {
    @EnvironmentObject var appSettings: AppSettings
    @State private var viewModel: TumIslemlerViewModel
    
    @State private var filtreEkraniGosteriliyor = false
    
    // 'duzenlemeEkraniGosteriliyor' boolean state'i kaldırıldı.
    @State private var duzenlenecekIslem: Islem?
    @State private var silinecekIslem: Islem?
    
    init(modelContext: ModelContext) {
        _viewModel = State(initialValue: TumIslemlerViewModel(modelContext: modelContext))
    }
    
    var body: some View {
        List {
            ForEach(viewModel.islemler) { islem in
                IslemSatirView(
                    islem: islem,
                    onEdit: {
                        // Sadece düzenlenecek işlemi set ediyoruz.
                        duzenlenecekIslem = islem
                    },
                    onDelete: {
                        silmeyiBaslat(islem)
                    }
                )
            }
        }
        .listStyle(.plain)
        .navigationTitle("all_transactions.title")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("all_transactions.filter_button") {
                    filtreEkraniGosteriliyor = true
                }
            }
        }
        .sheet(isPresented: $filtreEkraniGosteriliyor) {
            FiltreAyarView(ayarlar: $viewModel.filtreAyarlari)
                .environmentObject(appSettings)
        }
        .sheet(item: $duzenlenecekIslem, onDismiss: { viewModel.fetchData() }) { islem in
            IslemEkleView(duzenlenecekIslem: islem)
                .environmentObject(appSettings)
        }
        .overlay {
            if viewModel.islemler.isEmpty {
                ContentUnavailableView("all_transactions.not_found", systemImage: "magnifyingglass", description: Text("all_transactions.not_found_desc"))
            }
        }
        .recurringTransactionAlert(
            for: $silinecekIslem,
            onDeleteSingle: { islem in
                viewModel.deleteIslem(islem)
            },
            onDeleteSeries: { islem in
                viewModel.deleteSeri(islem)
            }
        )
    }
    
    private func silmeyiBaslat(_ islem: Islem) {
        if islem.tekrar != .tekSeferlik && islem.tekrarID != UUID() {
            silinecekIslem = islem
        } else {
            viewModel.deleteIslem(islem)
        }
    }
}
