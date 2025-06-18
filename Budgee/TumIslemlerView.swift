import SwiftUI
import SwiftData

struct TumIslemlerView: View {
    @EnvironmentObject var appSettings: AppSettings
    @Environment(\.dismiss) private var dismiss
    
    @State private var viewModel: TumIslemlerViewModel
    
    // Her bir filtre sayfası için ayrı state'ler
    @State private var kategoriFiltreGosteriliyor = false
    @State private var tarihFiltreGosteriliyor = false
    @State private var turFiltreGosteriliyor = false
    
    @State private var duzenlenecekIslem: Islem?
    @State private var silinecekIslem: Islem?
    
    init(modelContext: ModelContext) {
        _viewModel = State(initialValue: TumIslemlerViewModel(modelContext: modelContext))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            filtrelemeBari
                .padding(.vertical, 8)

            List {
                ForEach(viewModel.islemler) { islem in
                    IslemSatirView(
                        islem: islem,
                        onEdit: { duzenlenecekIslem = islem },
                        onDelete: { silmeyiBaslat(islem) }
                    )
                }
            }
            .listStyle(.plain)
        }
        .navigationTitle("all_transactions.title")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    dismiss()
                }) {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("common.back")
                    }
                }
            }
        }
        .sheet(isPresented: $kategoriFiltreGosteriliyor, onDismiss: { viewModel.fetchData() }) {
            KategoriSecimView(secilenKategoriler: $viewModel.filtreAyarlari.secilenKategoriler)
                .environmentObject(appSettings)
        }
        .sheet(isPresented: $tarihFiltreGosteriliyor, onDismiss: { viewModel.fetchData() }) {
            TarihAraligiSecimView(secilenAralik: $viewModel.filtreAyarlari.tarihAraligi)
                .presentationDetents([.height(320)])
                .environmentObject(appSettings)
        }
        .sheet(isPresented: $turFiltreGosteriliyor, onDismiss: { viewModel.fetchData() }) {
            IslemTuruSecimView(secilenTurler: $viewModel.filtreAyarlari.secilenTurler)
                .presentationDetents([.height(200)])
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
            onDeleteSingle: { islem in viewModel.deleteIslem(islem) },
            onDeleteSeries: { islem in viewModel.deleteSeri(islem) }
        )
    }
    
    private func silmeyiBaslat(_ islem: Islem) {
        if islem.tekrar != .tekSeferlik && islem.tekrarID != UUID() {
            silinecekIslem = islem
        } else {
            viewModel.deleteIslem(islem)
        }
    }
    
    private var filtrelemeBari: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Menu {
                    Picker(LocalizedStringKey("filter.sort_by"), selection: $viewModel.filtreAyarlari.sortOrder) {
                        ForEach(SortOrder.allCases) { order in
                            Text(LocalizedStringKey(order.rawValue)).tag(order)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.arrow.down")
                        Text("filter.sort_by")
                    }
                }
                .buttonStyle(FiltreButonStyle())

                Button(action: { kategoriFiltreGosteriliyor = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                        Text("common.categories")
                    }
                }
                .buttonStyle(FiltreButonStyle(aktif: !viewModel.filtreAyarlari.secilenKategoriler.isEmpty))
                .overlay(alignment: .topTrailing) {
                    if !viewModel.filtreAyarlari.secilenKategoriler.isEmpty {
                        Text(String(viewModel.filtreAyarlari.secilenKategoriler.count))
                            .font(.caption2.bold())
                            .foregroundColor(.white)
                            .padding(5)
                            .background(Circle().fill(.red))
                            .offset(x: 8, y: -8)
                    }
                }
                
                Button { tarihFiltreGosteriliyor = true } label: { Text("filter.date_range") }
                    .buttonStyle(FiltreButonStyle(aktif: viewModel.filtreAyarlari.tarihAraligi != .hepsi))
                
                Button { turFiltreGosteriliyor = true } label: { Text("transaction.type") }
                    .buttonStyle(FiltreButonStyle(aktif: viewModel.filtreAyarlari.secilenTurler.count == 1))
            }
            .padding(.horizontal)
        }
    }
}
