//
//  HarcamaIsiHaritasiView.swift
//  Walleo
//
//  Created by Mustafa Turan on 15.07.2025.
//


// >> YENİ DOSYA: Features/ReportsDetailed/Views/HarcamaIsiHaritasiView.swift

import SwiftUI
import SwiftData

struct HarcamaIsiHaritasiView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appSettings: AppSettings
    
    @State private var viewModel: HarcamaIsiHaritasiViewModel
    
    let baslangicTarihi: Date
    let bitisTarihi: Date
    
    init(modelContext: ModelContext, baslangicTarihi: Date, bitisTarihi: Date) {
        self.baslangicTarihi = baslangicTarihi
        self.bitisTarihi = bitisTarihi
        
        // appSettings'i burada alamayız, onAppear'da ayarlayacağız
        _viewModel = State(initialValue: HarcamaIsiHaritasiViewModel(
            modelContext: modelContext,
            baslangicTarihi: baslangicTarihi,
            bitisTarihi: bitisTarihi,
            appSettings: AppSettings() // Geçici olarak boş instance
        ))
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if viewModel.isLoading {
                    ProgressView("Yükleniyor...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.top, 100)
                } else if viewModel.isiHaritasiVerisi == nil {
                    ContentUnavailableView(
                        LocalizedStringKey("reports.heatmap.no_data"),
                        systemImage: "chart.xyaxis.line",
                        description: Text("Farklı bir tarih aralığı deneyin")
                    )
                    .padding(.top, 100)
                } else {
                    // Ana ısı haritası
                    AdaptifIsiHaritasi(
                        veriler: viewModel.isiHaritasiVerisi!.zamanDilimleri,
                        gunSayisi: viewModel.isiHaritasiVerisi!.gunSayisi
                    )
                    .padding(.horizontal)
                    
                    // Alt grafikler
                    VStack(spacing: 20) {
                        // 24 Saatlik Radyal Grafik
                        RadyalSaatGrafigi(
                            saatlikDagilim: viewModel.saatlikDagilim
                        )
                        .padding(.horizontal)
                        
                        // Periyodik Karşılaştırma
                        PeriyodikKarsilastirmaView(
                            veriler: viewModel.karsilastirmaVerileri
                        )
                        .padding(.horizontal)
                    }
                    
                    // Akıllı İçgörüler
                    if !viewModel.icgoruler.isEmpty {
                        AkilliIcgorulerPaneli(
                            icgoruler: viewModel.icgoruler
                        )
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
        .onAppear {
            // appSettings'i güncelle
            viewModel = HarcamaIsiHaritasiViewModel(
                modelContext: modelContext,
                baslangicTarihi: baslangicTarihi,
                bitisTarihi: bitisTarihi,
                appSettings: appSettings
            )
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
    }
}
