import SwiftUI
import SwiftData
import Charts

struct KategoriRaporuView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appSettings: AppSettings
    @State private var viewModel: KategoriRaporuViewModel
    
    @State private var secilenKategori: Kategori?
    @State private var gosterimTipi: GosterimTipi = .liste
    
    let baslangicTarihi: Date
    let bitisTarihi: Date
    
    enum GosterimTipi: String, CaseIterable {
        case liste = "reports.category.view_list"
        case grafik = "reports.category.view_chart"
        case karsilastirma = "reports.category.view_comparison"
    }
    
    init(modelContext: ModelContext, baslangicTarihi: Date, bitisTarihi: Date) {
        self.baslangicTarihi = baslangicTarihi
        self.bitisTarihi = bitisTarihi
        _viewModel = State(initialValue: KategoriRaporuViewModel(
            modelContext: modelContext,
            baslangicTarihi: baslangicTarihi,
            bitisTarihi: bitisTarihi
        ))
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if viewModel.isLoading {
                    ProgressView(LocalizedStringKey("common.loading"))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.top, 100)
                } else {
                    // Özet Kartı
                    KategoriOzetKarti(ozet: viewModel.ozet)
                        .padding(.horizontal)
                    
                    // Gösterim tipi seçici
                    Picker("reports.category.display_type", selection: $gosterimTipi) {
                        ForEach(GosterimTipi.allCases, id: \.self) { tip in
                            Text(LocalizedStringKey(tip.rawValue)).tag(tip)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    // İçerik
                    switch gosterimTipi {
                    case .liste:
                        listeGorunumu
                    case .grafik:
                        grafikGorunumu
                    case .karsilastirma:
                        karsilastirmaGorunumu
                    }
                }
            }
            .padding(.vertical)
        }
        .sheet(item: $secilenKategori) { kategori in
            if let rapor = viewModel.giderKategorileri.first(where: { $0.kategori.id == kategori.id }) ??
                          viewModel.gelirKategorileri.first(where: { $0.kategori.id == kategori.id }) {
                KategoriDetayView(rapor: rapor)
                    .environmentObject(appSettings)
            }
        }
        .onAppear {
            viewModel.appSettings = appSettings
            Task { await viewModel.fetchData() }
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
        .onChange(of: appSettings.languageCode) {
            viewModel.appSettings = appSettings
            Task { await viewModel.fetchData() }
        }
    }
    
    @ViewBuilder
    private var listeGorunumu: some View {
        VStack(spacing: 20) {
            // Tür seçici
            Picker("reports.category.transaction_type", selection: $viewModel.secilenTur) {
                Text("common.expenses").tag(IslemTuru.gider)
                Text("common.incomes").tag(IslemTuru.gelir)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .onChange(of: viewModel.secilenTur) {
                Task { await viewModel.fetchData() }
            }
            
            // Kategori listesi
            let kategoriler = viewModel.secilenTur == .gider ? viewModel.giderKategorileri : viewModel.gelirKategorileri
            
            ForEach(kategoriler) { rapor in
                KategoriListeKarti(rapor: rapor) {
                    secilenKategori = rapor.kategori
                }
                .padding(.horizontal)
            }
        }
    }
    
    @ViewBuilder
    private var grafikGorunumu: some View {
        VStack(spacing: 20) {
            // Pasta grafiği
            if !viewModel.giderKategorileri.isEmpty || !viewModel.gelirKategorileri.isEmpty {
                VStack(alignment: .leading, spacing: 20) {
                    Text("reports.category.distribution")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    // Grafikler yan yana değil alt alta olacak
                    VStack(spacing: 30) {
                        // Gider pasta grafiği ve detayları
                        if !viewModel.giderKategorileri.isEmpty {
                            VStack(spacing: 20) {
                                VStack(spacing: 12) {
                                    Text("common.expense")
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.red)
                                    
                                    DonutChartView(data: viewModel.giderKategorileri.map { rapor in
                                        KategoriHarcamasi(
                                            kategori: rapor.kategori.isim,
                                            tutar: rapor.toplamTutar,
                                            renk: rapor.kategori.renk,
                                            localizationKey: rapor.kategori.localizationKey,
                                            ikonAdi: rapor.kategori.ikonAdi
                                        )
                                    })
                                    .frame(height: 220)
                                }
                                
                                // Gider kategorileri listesi
                                VStack(spacing: 12) {
                                    ForEach(viewModel.giderKategorileri.prefix(5)) { rapor in
                                        kategoriDetaySatiri(rapor: rapor, toplamTutar: viewModel.ozet.toplamHarcama)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                        
                        // Ayırıcı
                        if !viewModel.giderKategorileri.isEmpty && !viewModel.gelirKategorileri.isEmpty {
                            Divider()
                                .padding(.horizontal, 40)
                        }
                        
                        // Gelir pasta grafiği ve detayları
                        if !viewModel.gelirKategorileri.isEmpty {
                            VStack(spacing: 20) {
                                VStack(spacing: 12) {
                                    Text("common.income")
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.green)
                                    
                                    DonutChartView(data: viewModel.gelirKategorileri.map { rapor in
                                        KategoriHarcamasi(
                                            kategori: rapor.kategori.isim,
                                            tutar: rapor.toplamTutar,
                                            renk: rapor.kategori.renk,
                                            localizationKey: rapor.kategori.localizationKey,
                                            ikonAdi: rapor.kategori.ikonAdi
                                        )
                                    })
                                    .frame(height: 220)
                                }
                                
                                // Gelir kategorileri listesi
                                VStack(spacing: 12) {
                                    ForEach(viewModel.gelirKategorileri.prefix(5)) { rapor in
                                        kategoriDetaySatiri(rapor: rapor, toplamTutar: viewModel.ozet.toplamGelir)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(16)
                .padding(.horizontal)
            }
        }
    }

    // Yeni yardımcı fonksiyon - kategori detay satırı
    @ViewBuilder
    private func kategoriDetaySatiri(rapor: KategoriRaporVerisi, toplamTutar: Double) -> some View {
        HStack(spacing: 12) {
            // İkon
            Image(systemName: rapor.kategori.ikonAdi)
                .font(.title3)
                .foregroundColor(rapor.kategori.renk)
                .frame(width: 36, height: 36)
                .background(rapor.kategori.renk.opacity(0.15))
                .cornerRadius(8)
            
            // Kategori adı ve yüzde
            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey(rapor.kategori.localizationKey ?? rapor.kategori.isim))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                // Yüzde bilgisi
                Text(String(format: "%.1f%%", toplamTutar > 0 ? (rapor.toplamTutar / toplamTutar) * 100 : 0))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Tutar
            Text(formatCurrency(
                amount: rapor.toplamTutar,
                currencyCode: appSettings.currencyCode,
                localeIdentifier: appSettings.languageCode
            ))
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundColor(.primary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.tertiarySystemGroupedBackground))
        .cornerRadius(10)
    }
    
    @ViewBuilder
    private var karsilastirmaGorunumu: some View {
        VStack(spacing: 20) {
            if !viewModel.kategoriKarsilastirmalari.isEmpty {
                ForEach(viewModel.kategoriKarsilastirmalari) { karsilastirma in
                    KategoriKarsilastirmaKarti(karsilastirma: karsilastirma)
                        .padding(.horizontal)
                }
            } else {
                ContentUnavailableView(
                    LocalizedStringKey("reports.category.no_comparison_data"),
                    systemImage: "chart.line.uptrend.xyaxis",
                    description: Text("reports.category.no_previous_period")
                )
                .padding(.top, 50)
            }
        }
    }
}

// Özet kartı
struct KategoriOzetKarti: View {
    let ozet: KategoriRaporOzet
    @EnvironmentObject var appSettings: AppSettings
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("reports.category.summary")
                .font(.title2.bold())
            
            HStack(spacing: 20) {
                VStack(alignment: .leading) {
                    Text("reports.category.total_categories")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(ozet.toplamKategoriSayisi)")
                        .font(.title.bold())
                }
                
                Divider()
                
                VStack(alignment: .leading) {
                    Text("reports.category.active_categories")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(ozet.aktifKategoriSayisi)")
                        .font(.title.bold())
                        .foregroundColor(.green)
                }
                
                Spacer()
            }
            
            if let enCokHarcanan = ozet.enCokHarcananKategori {
                HStack {
                    Image(systemName: "trophy.fill")
                        .foregroundColor(.orange)
                    Text("reports.category.most_spent")
                        .font(.subheadline)
                    Spacer()
                    HStack {
                        Image(systemName: enCokHarcanan.ikonAdi)
                            .foregroundColor(enCokHarcanan.renk)
                        Text(LocalizedStringKey(enCokHarcanan.localizationKey ?? enCokHarcanan.isim))
                            .fontWeight(.medium)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}
