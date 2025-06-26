import SwiftUI
import SwiftData

struct TumIslemlerView: View {
    @EnvironmentObject var appSettings: AppSettings
    @Environment(\.dismiss) private var dismiss
    
    @State private var viewModel: TumIslemlerViewModel
    
    @State private var kategoriFiltreGosteriliyor = false
    @State private var tarihFiltreGosteriliyor = false
    @State private var turFiltreGosteriliyor = false
    
    @State private var duzenlenecekIslem: Islem?
    @State private var silinecekTekrarliIslem: Islem?
    @State private var silinecekTekilIslem: Islem?
    
    init(modelContext: ModelContext) {
        _viewModel = State(initialValue: TumIslemlerViewModel(modelContext: modelContext))
    }
    
    var body: some View {
        ZStack {
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
            .disabled(viewModel.isDeleting)
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
            .sheet(isPresented: $kategoriFiltreGosteriliyor) {
                KategoriSecimView(secilenKategoriler: $viewModel.filtreAyarlari.secilenKategoriler)
                    .environmentObject(appSettings)
            }
            .sheet(isPresented: $tarihFiltreGosteriliyor) {
                TarihAraligiSecimView(secilenAralik: $viewModel.filtreAyarlari.tarihAraligi)
                    .presentationDetents([.height(320)])
                    .environmentObject(appSettings)
            }
            .sheet(isPresented: $turFiltreGosteriliyor) {
                IslemTuruSecimView(secilenTurler: $viewModel.filtreAyarlari.secilenTurler)
                    .presentationDetents([.height(200)])
                    .environmentObject(appSettings)
            }
            .sheet(item: $duzenlenecekIslem) { islem in
                IslemEkleView(duzenlenecekIslem: islem)
                    .environmentObject(appSettings)
            }
            .overlay {
                if viewModel.islemler.isEmpty && !viewModel.isDeleting {
                    ContentUnavailableView("all_transactions.not_found", systemImage: "magnifyingglass", description: Text("all_transactions.not_found_desc"))
                }
            }
            .recurringTransactionAlert(
                for: $silinecekTekrarliIslem,
                onDeleteSingle: { islem in viewModel.deleteIslem(islem) },
                onDeleteSeries: { islem in viewModel.deleteSeri(islem) }
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
            
            if viewModel.isDeleting {
                ProgressView("Siliniyor...")
                    .padding(25)
                    .background(Material.thick)
                    .cornerRadius(10)
                    .shadow(radius: 5)
            }
        }
    }
    
    private func silmeyiBaslat(_ islem: Islem) {
        if islem.tekrar != .tekSeferlik && islem.tekrarID != UUID() {
            silinecekTekrarliIslem = islem
        } else {
            silinecekTekilIslem = islem
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
