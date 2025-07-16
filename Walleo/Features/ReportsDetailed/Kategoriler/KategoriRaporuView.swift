//
//  KategoriRaporuView.swift
//  Walleo
//
//  Created by Mustafa Turan on 17.07.2025.
//


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
                    ProgressView("Yükleniyor...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.top, 100)
                } else {
                    // Özet Kartı
                    KategoriOzetKarti(ozet: viewModel.ozet)
                        .padding(.horizontal)
                    
                    // Gösterim tipi seçici
                    Picker("Gösterim Tipi", selection: $gosterimTipi) {
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
        .onAppear { Task { await viewModel.fetchData() } }
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
    
    @ViewBuilder
    private var listeGorunumu: some View {
        VStack(spacing: 20) {
            // Tür seçici
            Picker("İşlem Türü", selection: $viewModel.secilenTur) {
                Text("Giderler").tag(IslemTuru.gider)
                Text("Gelirler").tag(IslemTuru.gelir)
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
                VStack(alignment: .leading, spacing: 16) {
                    Text("reports.category.distribution")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    HStack(alignment: .top, spacing: 0) {
                        // Gider pasta grafiği ve detayları
                        if !viewModel.giderKategorileri.isEmpty {
                            VStack(spacing: 16) {
                                VStack(spacing: 8) {
                                    Text("common.expense")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.secondary)
                                    
                                    DonutChartView(data: viewModel.giderKategorileri.map { rapor in
                                        KategoriHarcamasi(
                                            kategori: rapor.kategori.isim,
                                            tutar: rapor.toplamTutar,
                                            renk: rapor.kategori.renk,
                                            localizationKey: rapor.kategori.localizationKey,
                                            ikonAdi: rapor.kategori.ikonAdi
                                        )
                                    })
                                    .frame(height: 200)
                                }
                                
                                // Gider kategorileri listesi
                                VStack(spacing: 8) {
                                    ForEach(viewModel.giderKategorileri.prefix(5)) { rapor in
                                        kategoriDetaySatiri(rapor: rapor, toplamTutar: viewModel.ozet.toplamHarcama)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        
                        // Ayırıcı çizgi
                        if !viewModel.giderKategorileri.isEmpty && !viewModel.gelirKategorileri.isEmpty {
                            Divider()
                                .frame(width: 1)
                                .background(Color.gray.opacity(0.3))
                                .padding(.vertical, 20)
                        }
                        
                        // Gelir pasta grafiği ve detayları
                        if !viewModel.gelirKategorileri.isEmpty {
                            VStack(spacing: 16) {
                                VStack(spacing: 8) {
                                    Text("common.income")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.secondary)
                                    
                                    DonutChartView(data: viewModel.gelirKategorileri.map { rapor in
                                        KategoriHarcamasi(
                                            kategori: rapor.kategori.isim,
                                            tutar: rapor.toplamTutar,
                                            renk: rapor.kategori.renk,
                                            localizationKey: rapor.kategori.localizationKey,
                                            ikonAdi: rapor.kategori.ikonAdi
                                        )
                                    })
                                    .frame(height: 200)
                                }
                                
                                // Gelir kategorileri listesi
                                VStack(spacing: 8) {
                                    ForEach(viewModel.gelirKategorileri.prefix(5)) { rapor in
                                        kategoriDetaySatiri(rapor: rapor, toplamTutar: viewModel.ozet.toplamGelir)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(12)
                .padding(.horizontal)
            }
        }
    }

    // Yeni yardımcı fonksiyon - kategori detay satırı
    @ViewBuilder
    private func kategoriDetaySatiri(rapor: KategoriRaporVerisi, toplamTutar: Double) -> some View {
        HStack(spacing: 8) {
            // İkon
            Image(systemName: rapor.kategori.ikonAdi)
                .font(.caption)
                .foregroundColor(rapor.kategori.renk)
                .frame(width: 24, height: 24)
                .background(rapor.kategori.renk.opacity(0.15))
                .cornerRadius(6)
            
            // Kategori adı
            Text(LocalizedStringKey(rapor.kategori.localizationKey ?? rapor.kategori.isim))
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)
            
            Spacer()
            
            // Yüzde
            Text(String(format: "%.1f%%", toplamTutar > 0 ? (rapor.toplamTutar / toplamTutar) * 100 : 0))
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 45, alignment: .trailing)
            
            // Tutar
            Text(formatCurrency(
                amount: rapor.toplamTutar,
                currencyCode: appSettings.currencyCode,
                localeIdentifier: appSettings.languageCode
            ))
            .font(.caption)
            .fontWeight(.semibold)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .frame(width: 80, alignment: .trailing)
        }
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
                    "Karşılaştırma Verisi Yok",
                    systemImage: "chart.line.uptrend.xyaxis",
                    description: Text("Önceki dönem verisi bulunamadı")
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
