// Dosya: TumIslemlerView.swift

import SwiftUI
import SwiftData

struct TumIslemlerView: View {
    @EnvironmentObject var appSettings: AppSettings
    @Environment(\.dismiss) private var dismiss
    
    @State private var viewModel: TumIslemlerViewModel
    
    @State private var kategoriFiltreGosteriliyor = false
    @State private var tarihFiltreGosteriliyor = false
    @State private var turFiltreGosteriliyor = false
    @State private var hesapFiltreGosteriliyor = false
    
    @State private var duzenlenecekIslem: Islem?
    @State private var silinecekTekrarliIslem: Islem?
    @State private var silinecekTekilIslem: Islem?
    @State private var silinecekTaksitliIslem: Islem?
    @State private var searchText = ""  // YENİ: Arama metni state'i
    
    // YENİ: Scroll performansı için
    @State private var scrollViewProxy: ScrollViewProxy?
    @State private var isScrolling = false
    
    init(modelContext: ModelContext, baslangicTarihi: Date? = nil) {
        _viewModel = State(initialValue: TumIslemlerViewModel(modelContext: modelContext, baslangicTarihi: baslangicTarihi))
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // YENİ: Filtre barını optimize et
                filtrelemeBari
                    .padding(.vertical, 8)
                
                // YENİ: Liste performansını artır
                optimizedListView
            }
            .disabled(viewModel.isDeleting)
            .navigationTitle("all_transactions.title")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    backButton
                }
            }
            // Sheet'ler
            .sheet(isPresented: $kategoriFiltreGosteriliyor) {
                KategoriSecimView(secilenKategoriler: $viewModel.filtreAyarlari.secilenKategoriler)
                    .environmentObject(appSettings)
                    .onDisappear {
                        viewModel.onFilterChanged()
                    }
            }
            .sheet(isPresented: $hesapFiltreGosteriliyor) {
                HesapSecimFiltreView(secilenHesaplar: $viewModel.filtreAyarlari.secilenHesaplar)
                    .onDisappear {
                        viewModel.onFilterChanged()
                    }
            }
            .sheet(isPresented: $tarihFiltreGosteriliyor) {
                TarihAraligiSecimView(filtreAyarlari: $viewModel.filtreAyarlari)
                    .environmentObject(appSettings)
                    .onDisappear {
                        viewModel.invalidateCacheAndFetch()
                    }
            }
            .sheet(isPresented: $turFiltreGosteriliyor) {
                IslemTuruSecimView(secilenTurler: $viewModel.filtreAyarlari.secilenTurler)
                    .presentationDetents([.height(200)])
                    .environmentObject(appSettings)
                    .onDisappear {
                        viewModel.invalidateCacheAndFetch()
                    }
            }
            .sheet(item: $duzenlenecekIslem) { islem in
                IslemEkleView(duzenlenecekIslem: islem)
                    .environmentObject(appSettings)
            }
            // Alert'ler
            .recurringTransactionAlert(
                for: $silinecekTekrarliIslem,
                onDeleteSingle: { islem in viewModel.deleteIslem(islem) },
                onDeleteSeries: { islem in viewModel.deleteSeri(islem) }
            )
            .alert(
                LocalizedStringKey("alert.installment.delete_title"),
                isPresented: Binding(isPresented: $silinecekTaksitliIslem),
                presenting: silinecekTaksitliIslem
            ) { islem in
                Button(role: .destructive) {
                    viewModel.deleteTaksitliIslem(islem)
                } label: {
                    Text("common.delete")
                }
            } message: { islem in
                Text(String(format: NSLocalizedString("transaction.installment.delete_warning", comment: ""), islem.toplamTaksitSayisi))
            }
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
            
            // YENİ: Loading overlay
            if viewModel.isLoading && viewModel.islemler.isEmpty {
                loadingView
            }
            
            // Delete overlay
            if viewModel.isDeleting {
                deleteProgressView
            }
        }
        .onAppear {
            // View göründüğünde veriyi yükle
            if viewModel.islemler.isEmpty {
                viewModel.fetchData()
            }
        }
    }
    
    // YENİ: Optimize edilmiş liste view
    @ViewBuilder
    private var optimizedListView: some View {
        VStack(spacing: 0) {
            // YENİ: Arama alanı
            searchBarView
                .padding(.horizontal)
                .padding(.bottom, 8)
            
            if viewModel.islemler.isEmpty && !viewModel.isLoading {
                emptyStateView
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0, pinnedViews: []) {
                            ForEach(Array(viewModel.islemler.enumerated()), id: \.element.id) { index, islem in
                                VStack(spacing: 0) {
                                    // YENİ: Her satırı optimize et
                                    OptimizedTransactionRow(
                                        islem: islem,
                                        onEdit: { duzenlenecekIslem = islem },
                                        onDelete: { silmeyiBaslat(islem) }
                                    )
                                    .id(islem.id)
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                                    
                                    if index < viewModel.islemler.count - 1 {
                                        Divider()
                                            .padding(.leading, 60)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .onAppear {
                        scrollViewProxy = proxy
                    }
                    // YENİ: Scroll performansını artır
                    .scrollDismissesKeyboard(.immediately)
                    .scrollIndicators(.hidden)
                }
            }
        }
    }
    
    // YENİ: Arama alanı view'ı
    @ViewBuilder
    private var searchBarView: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .padding(.leading, 8)
            
            TextField(LocalizedStringKey("search.placeholder"), text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .submitLabel(.search)
                .onChange(of: searchText) { _, newValue in
                    viewModel.searchText = newValue
                    viewModel.onFilterChanged()
                }
            
            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                    viewModel.searchText = ""
                    viewModel.onFilterChanged()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .padding(.trailing, 8)
            }
        }
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
    
    // YENİ: Back button
    @ViewBuilder
    private var backButton: some View {
        Button(action: { dismiss() }) {
            HStack(spacing: 4) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                Text("common.back")
            }
        }
    }
    
    // YENİ: Empty state
    @ViewBuilder
    private var emptyStateView: some View {
        ContentUnavailableView(
            "all_transactions.not_found",
            systemImage: "magnifyingglass",
            description: Text("all_transactions.not_found_desc")
        )
    }
    
    // YENİ: Loading view
    @ViewBuilder
    private var loadingView: some View {
        VStack {
            ProgressView()
                .scaleEffect(1.5)
                .padding()
            Text("Loading...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.3))
    }
    
    // YENİ: Delete progress view
    @ViewBuilder
    private var deleteProgressView: some View {
        ProgressView("Siliniyor...")
            .padding(25)
            .background(Material.thick)
            .cornerRadius(10)
            .shadow(radius: 5)
    }
    
    private func silmeyiBaslat(_ islem: Islem) {
        if islem.taksitliMi {
            silinecekTaksitliIslem = islem
        } else if islem.tekrar != .tekSeferlik && islem.tekrarID != UUID() {
            silinecekTekrarliIslem = islem
        } else {
            silinecekTekilIslem = islem
        }
    }
    
    // YENİ: Optimize edilmiş filtre barı
    private var filtrelemeBari: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Sort menu
                sortMenu
                
                // Category filter
                filterButton(
                    title: "common.categories",
                    icon: "line.3.horizontal.decrease.circle",
                    isActive: !viewModel.filtreAyarlari.secilenKategoriler.isEmpty,
                    count: viewModel.filtreAyarlari.secilenKategoriler.count,
                    action: { kategoriFiltreGosteriliyor = true }
                )
                
                // Account filter
                filterButton(
                    title: "filter.accounts",
                    icon: "wallet.pass.fill",
                    isActive: !viewModel.filtreAyarlari.secilenHesaplar.isEmpty,
                    count: viewModel.filtreAyarlari.secilenHesaplar.count,
                    action: { hesapFiltreGosteriliyor = true }
                )
                
                // Date range filter
                Button { tarihFiltreGosteriliyor = true } label: {
                    Text("filter.date_range")
                }
                .buttonStyle(FiltreButonStyle(aktif: viewModel.filtreAyarlari.tarihAraligi != .buAy))
                
                // Transaction type filter
                Button { turFiltreGosteriliyor = true } label: {
                    Text("transaction.type")
                }
                .buttonStyle(FiltreButonStyle(aktif: viewModel.filtreAyarlari.secilenTurler.count == 1))
            }
            .padding(.horizontal)
        }
    }
    
    // YENİ: Sort menu
    @ViewBuilder
    private var sortMenu: some View {
        Menu {
            Picker(LocalizedStringKey("filter.sort_by"), selection: Binding(
                get: { viewModel.filtreAyarlari.sortOrder },
                set: { newValue in
                    viewModel.filtreAyarlari.sortOrder = newValue
                    viewModel.invalidateCacheAndFetch()
                }
            )) {
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
    }
    
    // YENİ: Filter button helper
    @ViewBuilder
    private func filterButton(
        title: LocalizedStringKey,
        icon: String,
        isActive: Bool,
        count: Int,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                Text(title)
            }
        }
        .buttonStyle(FiltreButonStyle(aktif: isActive))
        .overlay(alignment: .topTrailing) {
            if count > 0 {
                Text(String(count))
                    .font(.caption2.bold())
                    .foregroundColor(.white)
                    .padding(5)
                    .background(Circle().fill(.red))
                    .offset(x: 8, y: -8)
            }
        }
    }
}

// YENİ: Optimize edilmiş işlem satırı
struct OptimizedTransactionRow: View {
    @EnvironmentObject var appSettings: AppSettings
    let islem: Islem
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        IslemSatirView(
            islem: islem,
            onEdit: onEdit,
            onDelete: onDelete
        )
        .padding(.horizontal)
    }
}
