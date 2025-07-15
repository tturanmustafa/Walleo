// >> GÜNCELLENECEK DOSYA: Features/ReportsDetailed/KrediKartiRaporuView.swift

import SwiftUI
import SwiftData

struct KrediKartiRaporuView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appSettings: AppSettings
    
    @State private var viewModel: KrediKartiRaporuViewModel
    @State private var secilenSayfa: RaporSayfasi = .ozet
    @State private var secilenKartID: UUID?
    
    let baslangicTarihi: Date
    let bitisTarihi: Date
    
    enum RaporSayfasi: String, CaseIterable {
        case ozet = "reports.credit_card.tab.summary"
        case detay = "reports.credit_card.tab.details"
        case analiz = "reports.credit_card.tab.analysis"
        case tahmin = "reports.credit_card.tab.prediction"
    }
    
    init(modelContext: ModelContext, baslangicTarihi: Date, bitisTarihi: Date) {
        self.baslangicTarihi = baslangicTarihi
        self.bitisTarihi = bitisTarihi
        
        _viewModel = State(initialValue: KrediKartiRaporuViewModel(
            modelContext: modelContext,
            baslangicTarihi: baslangicTarihi,
            bitisTarihi: bitisTarihi
        ))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Sayfa seçici
            Picker("Rapor Sayfası", selection: $secilenSayfa.animation()) {
                ForEach(RaporSayfasi.allCases, id: \.self) { sayfa in
                    Text(LocalizedStringKey(sayfa.rawValue)).tag(sayfa)
                }
            }
            .pickerStyle(.segmented)
            .padding()
            
            if viewModel.isLoading {
                ProgressView("reports.loading")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.kartDetayRaporlari.isEmpty {
                ContentUnavailableView(
                    LocalizedStringKey("reports.credit_card.no_data"),
                    systemImage: "creditcard.fill",
                    description: Text(LocalizedStringKey("reports.credit_card.no_data.description"))
                )
            } else {
                TabView(selection: $secilenSayfa) {
                    // Özet Sayfası
                    KrediKartiOzetView(
                        genelOzet: viewModel.genelOzet,
                        kartRaporlari: viewModel.kartDetayRaporlari,
                        secilenKartID: $secilenKartID
                    )
                    .tag(RaporSayfasi.ozet)
                    
                    // Detay Sayfası
                    KrediKartiDetayView(
                        kartRaporlari: viewModel.kartDetayRaporlari,
                        secilenKartID: $secilenKartID
                    )
                    .tag(RaporSayfasi.detay)
                    
                    // Analiz Sayfası
                    KrediKartiAnalizView(
                        analiz: viewModel.harcamaAnalizi,
                        icgoruler: viewModel.icgoruler
                    )
                    .tag(RaporSayfasi.analiz)
                    
                    // Tahmin Sayfası
                    KrediKartiTahminView(
                        tahminler: viewModel.kartTahminleri,
                        genelTahmin: viewModel.genelTahmin
                    )
                    .tag(RaporSayfasi.tahmin)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: secilenSayfa)
            }
        }
        .task {
            await viewModel.fetchData()
        }
        .refreshable {
            await viewModel.fetchData()
        }
        .onChange(of: baslangicTarihi) {
            viewModel.baslangicTarihi = baslangicTarihi
            viewModel.bitisTarihi = bitisTarihi
            Task { await viewModel.fetchData() }
        }
        .onChange(of: bitisTarihi) {
            viewModel.baslangicTarihi = baslangicTarihi
            viewModel.bitisTarihi = bitisTarihi
            Task { await viewModel.fetchData() }
        }
    }
}
