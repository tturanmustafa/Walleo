import SwiftUI
import SwiftData

struct TumIslemlerView: View {
    @EnvironmentObject var appSettings: AppSettings
    // DEĞİŞİKLİK: @StateObject yerine @State kullanıyoruz.
    @State private var viewModel: TumIslemlerViewModel
    
    @State private var filtreEkraniGosteriliyor = false
    
    @State private var duzenlenecekIslem: Islem?
    @State private var duzenlemeEkraniGosteriliyor = false
    @State private var silinecekIslem: Islem?
    
    // DEĞİŞİKLİK: init metodunu @State'e uygun hale getiriyoruz.
    init(modelContext: ModelContext) {
        _viewModel = State(initialValue: TumIslemlerViewModel(modelContext: modelContext))
    }
    
    var body: some View {
        List {
            ForEach(viewModel.islemler) { islem in
                IslemSatirView(
                    islem: islem,
                    onEdit: {
                        duzenlenecekIslem = islem
                        duzenlemeEkraniGosteriliyor = true
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
        .sheet(isPresented: $duzenlemeEkraniGosteriliyor, onDismiss: {
            viewModel.fetchData()
        }) {
            IslemEkleView(duzenlenecekIslem: duzenlenecekIslem)
                .environmentObject(appSettings)
        }
        .overlay {
            if viewModel.islemler.isEmpty {
                ContentUnavailableView("all_transactions.not_found", systemImage: "magnifyingglass", description: Text("all_transactions.not_found_desc"))
            }
        }
        .confirmationDialog("alert.recurring_transaction", isPresented: .constant(silinecekIslem != nil), titleVisibility: .visible) {
            Button("alert.delete_this_only", role: .destructive) {
                if let islem = silinecekIslem { viewModel.deleteIslem(islem) }
                silinecekIslem = nil
            }
            Button("alert.delete_series", role: .destructive) {
                if let islem = silinecekIslem { viewModel.deleteSeri(islem) }
                silinecekIslem = nil
            }
            Button("common.cancel", role: .cancel) {
                silinecekIslem = nil
            }
        }
    }
    
    private func silmeyiBaslat(_ islem: Islem) {
        if islem.tekrar != .tekSeferlik && islem.tekrarID != UUID() {
            silinecekIslem = islem
        } else {
            viewModel.deleteIslem(islem)
        }
    }
}
