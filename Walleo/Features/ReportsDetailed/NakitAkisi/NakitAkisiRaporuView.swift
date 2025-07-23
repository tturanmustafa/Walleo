//
//  NakitAkisiRaporuView.swift
//  Walleo
//
//  Created by Mustafa Turan on 18.07.2025.
//


// Walleo/Features/ReportsDetailed/NakitAkisi/NakitAkisiRaporuView.swift

import SwiftUI
import SwiftData

struct NakitAkisiRaporuView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appSettings: AppSettings
    @State private var viewModel: NakitAkisiViewModel
    
    @State private var secilenGorunum: GorunumTipi = .ozet
    
    let baslangicTarihi: Date
    let bitisTarihi: Date
    
    enum GorunumTipi: String, CaseIterable {
        case ozet = "cashflow.view.summary"
        case akis = "cashflow.view.flow"
        case kategoriler = "cashflow.view.categories"
        case hesaplar = "cashflow.view.accounts"
    }
    
    init(modelContext: ModelContext, baslangicTarihi: Date, bitisTarihi: Date) {
        self.baslangicTarihi = baslangicTarihi
        self.bitisTarihi = bitisTarihi
        _viewModel = State(initialValue: NakitAkisiViewModel(
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
                } else if let rapor = viewModel.nakitAkisiRaporu {
                    // İçgörüler
                    if !viewModel.icgoruler.isEmpty {
                        NakitAkisiIcgoruleriView(icgoruler: viewModel.icgoruler)
                            .padding(.horizontal)
                    }
                    
                    // Görünüm seçici
                    Picker("Görünüm", selection: $secilenGorunum) {
                        ForEach(GorunumTipi.allCases, id: \.self) { tip in
                            Text(LocalizedStringKey(tip.rawValue)).tag(tip)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    // İçerik
                    switch secilenGorunum {
                    case .ozet:
                        ozetGorunumu(rapor: rapor)
                    case .akis:
                        akisGorunumu(rapor: rapor)
                    case .kategoriler:
                        kategorilerGorunumu(rapor: rapor)
                    case .hesaplar:
                        hesaplarGorunumu(rapor: rapor)
                    }
                } else {
                    ContentUnavailableView(
                        LocalizedStringKey("reports.cashflow.no_data_title"),
                        systemImage: "chart.line.uptrend.xyaxis",
                        description: Text(LocalizedStringKey("reports.cashflow.no_data_desc"))
                    )
                    .padding(.top, 100)
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
    
    // MARK: - Özet Görünümü
    @ViewBuilder
    private func ozetGorunumu(rapor: NakitAkisiRaporu) -> some View {
        VStack(spacing: 20) {
            // Ana metrikler
            NakitAkisiAnaMetriklerView(rapor: rapor)
                .padding(.horizontal)
            
            // İşlem tipi dağılımı - SADECE KARTLAR (GRAFİK KALDIRILDI)
            IslemTipiKartlariView(dagilim: rapor.islemTipiDagilimi)
                .padding(.horizontal)
            
            // Transfer özeti
            if rapor.transferOzeti.toplamTransferSayisi > 0 {
                TransferOzetiView(ozet: rapor.transferOzeti)
                    .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Akış Görünümü
    @ViewBuilder
    private func akisGorunumu(rapor: NakitAkisiRaporu) -> some View {
        VStack(spacing: 20) {
            // Nakit akış grafiği
            NakitAkisiGrafigiView(gunlukVeriler: rapor.gunlukAkisVerisi)
                .padding(.horizontal)
            
            // Detaylı akış listesi
            DetayliAkisListesiView(gunlukVeriler: rapor.gunlukAkisVerisi)
                .padding(.horizontal)
        }
    }
    
    // MARK: - Kategoriler Görünümü
    @ViewBuilder
    private func kategorilerGorunumu(rapor: NakitAkisiRaporu) -> some View {
        VStack(spacing: 20) {
            // Kategori akış grafiği
            KategoriAkisGrafigiView(kategoriler: rapor.kategoriAkislari)
                .padding(.horizontal)
            
            // Kategori detayları
            ForEach(rapor.kategoriAkislari) { kategoriAkis in
                KategoriAkisKartiView(kategoriAkis: kategoriAkis)
                    .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Hesaplar Görünümü
    @ViewBuilder
    private func hesaplarGorunumu(rapor: NakitAkisiRaporu) -> some View {
        VStack(spacing: 20) {
            ForEach(rapor.hesapAkislari) { hesapAkis in
                HesapAkisKartiView(hesapAkis: hesapAkis)
                    .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Projeksiyon Görünümü

}

// MARK: - İçgörüler View
struct NakitAkisiIcgoruleriView: View {
    let icgoruler: [NakitAkisiIcgoru]
    @State private var gorunurIcgoruIndex = 0
    @EnvironmentObject var appSettings: AppSettings // AppSettings'i ekle
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("cashflow.insights")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            if !icgoruler.isEmpty {
                TabView(selection: $gorunurIcgoruIndex) {
                    ForEach(Array(icgoruler.enumerated()), id: \.element.id) { index, icgoru in
                        
                        // Formatlama burada yapılıyor
                        let mesajMetni: String = {
                            let dilKodu = appSettings.languageCode
                            let languageBundle = Bundle.main.path(forResource: dilKodu, ofType: "lproj")
                                .flatMap(Bundle.init(path:)) ?? .main
                            
                            let formatString = languageBundle.localizedString(forKey: icgoru.mesajKey, value: "", table: nil)
                            return String(format: formatString, arguments: icgoru.parametreler)
                        }()
                        
                        HStack(spacing: 12) {
                            Image(systemName: icgoru.ikon)
                                .font(.title2)
                                .foregroundColor(icgoru.renk)
                                .frame(width: 40, height: 40)
                                .background(icgoru.renk.opacity(0.15))
                                .cornerRadius(8)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(LocalizedStringKey(icgoru.baslik))
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                
                                Text(mesajMetni) // Değişti
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                            
                            Spacer()
                        }
                        .padding()
                        .background(Color(.tertiarySystemGroupedBackground))
                        .cornerRadius(12)
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .frame(height: 100)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
}
