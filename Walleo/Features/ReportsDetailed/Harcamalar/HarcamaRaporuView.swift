//
//  HarcamaRaporuView.swift
//  Walleo
//
//  Created by Mustafa Turan on 20.07.2025.
//


// Features/ReportsDetailed/Harcamalar/HarcamaRaporuView.swift

import SwiftUI
import SwiftData
import Charts

struct HarcamaRaporuView: View {
    @State private var viewModel: HarcamaRaporuViewModel
    @EnvironmentObject var appSettings: AppSettings
    @State private var secilenGorunum: HarcamaGorunum = .ozet
    @State private var genisletilmisKategoriler: Set<UUID> = []
    
    let baslangicTarihi: Date
    let bitisTarihi: Date
    
    enum HarcamaGorunum: String, CaseIterable {
        case ozet = "spending_report.view.summary"
        case kategori = "spending_report.view.category"
        case zaman = "spending_report.view.time"
        case karsilastirma = "spending_report.view.comparison"
        
        var icon: String {
            switch self {
            case .ozet: return "chart.pie.fill"
            case .kategori: return "tag.fill"
            case .zaman: return "calendar"
            case .karsilastirma: return "chart.bar.fill"
            }
        }
    }
    
    init(modelContext: ModelContext, baslangicTarihi: Date, bitisTarihi: Date) {
        self.baslangicTarihi = baslangicTarihi
        self.bitisTarihi = bitisTarihi
        _viewModel = State(initialValue: HarcamaRaporuViewModel(
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
                } else if viewModel.toplamHarcama == 0 {
                    ContentUnavailableView(
                        LocalizedStringKey("spending_report.no_data"),
                        systemImage: "chart.line.downtrend.xyaxis",
                        description: Text(LocalizedStringKey("spending_report.no_data_desc"))
                    )
                    .padding(.top, 100)
                } else {
                    // Görünüm seçici
                    gorunumSecici
                        .padding(.horizontal)
                    
                    // İçerik
                    switch secilenGorunum {
                    case .ozet:
                        ozetGorunumu
                    case .kategori:
                        kategoriGorunumu
                    case .zaman:
                        zamanGorunumu
                    case .karsilastirma:
                        karsilastirmaGorunumu
                    }
                }
            }
            .padding(.vertical)
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
    
    // MARK: - Görünüm Seçici
    private var gorunumSecici: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(HarcamaGorunum.allCases, id: \.self) { gorunum in
                    Button(action: {
                        withAnimation(.spring(response: 0.3)) {
                            secilenGorunum = gorunum
                        }
                    }) {
                        VStack(spacing: 8) {
                            Image(systemName: gorunum.icon)
                                .font(.title2)
                            Text(LocalizedStringKey(gorunum.rawValue))
                                .font(.caption)
                        }
                        .foregroundColor(secilenGorunum == gorunum ? .white : .primary)
                        .frame(width: 80, height: 80)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(secilenGorunum == gorunum ? Color.accentColor : Color(.tertiarySystemGroupedBackground))
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - Özet Görünümü
    @ViewBuilder
    private var ozetGorunumu: some View {
        VStack(spacing: 20) {
            // Gelişmiş özet kartı
            HarcamaOzetKarti(ozet: viewModel.genelOzet)
                .padding(.horizontal)
            
            // En çok harcanan kategoriler
            EnCokHarcananKategoriler(kategoriler: viewModel.topKategoriler)
                .padding(.horizontal)
            
            // Haftalık özet
            HaftalikOzetGrafik(haftalikVeriler: viewModel.haftalikOzet)
                .padding(.horizontal)
            
            // Akıllı içgörüler
            if !viewModel.icgoruler.isEmpty {
                IcgorulerPaneli(icgoruler: viewModel.icgoruler)
                    .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Kategori Görünümü
    @ViewBuilder
    private var kategoriGorunumu: some View {
        VStack(spacing: 20) {
            // Kategori dağılım grafiği
            KategoriDagilimGrafigi(kategoriler: viewModel.kategoriDetaylari)
                .padding(.horizontal)
            
            // Detaylı kategori listesi
            ForEach(viewModel.kategoriDetaylari) { kategori in
                KategoriDetayKarti(
                    kategori: kategori,
                    isExpanded: genisletilmisKategoriler.contains(kategori.id),
                    onToggle: {
                        withAnimation {
                            if genisletilmisKategoriler.contains(kategori.id) {
                                genisletilmisKategoriler.remove(kategori.id)
                            } else {
                                genisletilmisKategoriler.insert(kategori.id)
                            }
                        }
                    }
                )
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Zaman Görünümü
    @ViewBuilder
    private var zamanGorunumu: some View {
        VStack(spacing: 20) {
            // Günlük harcama trendi
            GunlukHarcamaTrendi(gunlukVeriler: viewModel.gunlukHarcamalar)
                .padding(.horizontal)
            
            // Hafta içi vs hafta sonu
            HaftaIciSonuKarsilastirma(veriler: viewModel.haftaIciSonuKarsilastirma)
                .padding(.horizontal)
            
            // Saatlik dağılım (basitleştirilmiş)
            SaatlikDagilimGrafigi(saatlikVeriler: viewModel.saatlikDagilim)
                .padding(.horizontal)
        }
    }
    
    // MARK: - Karşılaştırma Görünümü
    @ViewBuilder
    private var karsilastirmaGorunumu: some View {
        VStack(spacing: 20) {
            // Önceki dönem karşılaştırması
            OncekiDonemKarsilastirma(karsilastirma: viewModel.donemKarsilastirma)
                .padding(.horizontal)
            
            // Kategori bazlı değişimler
            KategoriDegisimTablosu(degisimler: viewModel.kategoriDegisimleri)
                .padding(.horizontal)
            
            // Bütçe performansı
            if !viewModel.butcePerformansi.isEmpty {
                ButcePerformansKarti(performanslar: viewModel.butcePerformansi)
                    .padding(.horizontal)
            }
        }
    }
}