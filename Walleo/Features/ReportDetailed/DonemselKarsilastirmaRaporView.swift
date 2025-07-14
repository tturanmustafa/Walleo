//
//  DonemselKarsilastirmaRaporView.swift
//  Walleo
//
//  Created by Mustafa Turan on 14.07.2025.
//


import SwiftUI
import Charts

struct DonemselKarsilastirmaRaporView: View {
    @EnvironmentObject var appSettings: AppSettings
    @ObservedObject var viewModel: DetayliRaporlarViewModel
    @State private var secilenKiyasPeriyodu: KiyasPeriyodu = .oncekiAy
    @State private var animasyonTamamlandi = false
    
    enum KiyasPeriyodu: String, CaseIterable {
        case oncekiAy = "previous_month"
        case gecenYilBuAy = "last_year_same_month"
        case onceki3Ay = "previous_3_months"
        
        var localizedKey: LocalizedStringKey {
            LocalizedStringKey("detailed_reports.comparison.\(rawValue)")
        }
    }
    
    private var karsilastirmaVerisi: DonemselKarsilastirmaVerisi? {
        viewModel.donemselKarsilastirmaVerisi
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Periyot Seçici
                Picker("detailed_reports.comparison.period", selection: $secilenKiyasPeriyodu) {
                    ForEach(KiyasPeriyodu.allCases, id: \.self) { periyot in
                        Text(periyot.localizedKey).tag(periyot)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .onChange(of: secilenKiyasPeriyodu) { _ in
                    Task {
                        await viewModel.donemselKarsilastirmaGuncelle(periyot: secilenKiyasPeriyodu.rawValue)
                    }
                }
                
                if let veri = karsilastirmaVerisi {
                    // Ana Metrik Kartları
                    HStack(spacing: 16) {
                        DegisimKarti(
                            baslik: "common.income",
                            mevcutDeger: veri.mevcutGelir,
                            oncekiDeger: veri.oncekiGelir,
                            renk: .green
                        )
                        
                        DegisimKarti(
                            baslik: "common.expense",
                            mevcutDeger: veri.mevcutGider,
                            oncekiDeger: veri.oncekiGider,
                            renk: .red
                        )
                    }
                    .padding(.horizontal)
                    
                    // Net Değişim Kartı
                    NetDegisimKarti(
                        mevcutNet: veri.mevcutGelir - veri.mevcutGider,
                        oncekiNet: veri.oncekiGelir - veri.oncekiGider
                    )
                    .padding(.horizontal)
                    
                    // Kategori Karşılaştırma Grafiği
                    KategoriKarsilastirmaGrafigi(
                        mevcutKategoriler: veri.mevcutKategoriler,
                        oncekiKategoriler: veri.oncekiKategoriler
                    )
                    .frame(height: 400)
                    .padding()
                    
                    // En Çok Değişen Kategoriler
                    VStack(alignment: .leading, spacing: 12) {
                        Text("detailed_reports.comparison.biggest_changes")
                            .font(.headline)
                        
                        ForEach(veri.enCokDegisenler.prefix(5)) { degisim in
                            KategoriDegisimSatiri(degisim: degisim)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                } else {
                    ProgressView()
                        .frame(height: 300)
                }
            }
            .padding(.vertical)
        }
        .onAppear {
            if karsilastirmaVerisi == nil {
                Task {
                    await viewModel.donemselKarsilastirmaGuncelle(periyot: secilenKiyasPeriyodu.rawValue)
                }
            }
        }
    }
}

// Değişim Kartı Komponenti
struct DegisimKarti: View {
    @EnvironmentObject var appSettings: AppSettings
    let baslik: LocalizedStringKey
    let mevcutDeger: Double
    let oncekiDeger: Double
    let renk: Color
    
    @State private var animatedValue: Double = 0
    @State private var showDetails = false
    
    private var degisimYuzdesi: Double {
        guard oncekiDeger > 0 else { return 0 }
        return ((mevcutDeger - oncekiDeger) / oncekiDeger) * 100
    }
    
    private var degisimPozitif: Bool {
        mevcutDeger >= oncekiDeger
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(baslik)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(formatCurrency(
                amount: animatedValue,
                currencyCode: appSettings.currencyCode,
                localeIdentifier: appSettings.languageCode
            ))
            .font(.title2.bold())
            .foregroundColor(renk)
            
            HStack(spacing: 4) {
                Image(systemName: degisimPozitif ? "arrow.up.right" : "arrow.down.right")
                    .font(.caption.bold())
                
                Text(String(format: "%.1f%%", abs(degisimYuzdesi)))
                    .font(.caption.bold())
            }
            .foregroundColor(degisimPozitif ? .green : .red)
            
            if showDetails {
                Text("detailed_reports.comparison.previous_value")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text(formatCurrency(
                    amount: oncekiDeger,
                    currencyCode: appSettings.currencyCode,
                    localeIdentifier: appSettings.languageCode
                ))
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5)
        .onTapGesture {
            withAnimation(.spring()) {
                showDetails.toggle()
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                animatedValue = mevcutDeger
            }
        }
    }
}

// Kategori Karşılaştırma Grafiği
struct KategoriKarsilastirmaGrafigi: View {
    let mevcutKategoriler: [KategoriTutar]
    let oncekiKategoriler: [KategoriTutar]
    
    @State private var secilenKategori: String?
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("detailed_reports.comparison.category_chart")
                .font(.headline)
                .padding(.horizontal)
            
            Chart {
                ForEach(kategorileriEslestir()) { veri in
                    BarMark(
                        x: .value("Kategori", veri.kategoriAdi),
                        y: .value("Tutar", veri.mevcutTutar)
                    )
                    .foregroundStyle(.blue)
                    .position(by: .value("Dönem", "Mevcut"))
                    .opacity(secilenKategori == nil || secilenKategori == veri.kategoriAdi ? 1 : 0.3)
                    
                    BarMark(
                        x: .value("Kategori", veri.kategoriAdi),
                        y: .value("Tutar", veri.oncekiTutar)
                    )
                    .foregroundStyle(.gray)
                    .position(by: .value("Dönem", "Önceki"))
                    .opacity(secilenKategori == nil || secilenKategori == veri.kategoriAdi ? 1 : 0.3)
                }
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel(orientation: .vertical)
                }
            }
            .chartLegend(position: .top)
            .onTapGesture { location in
                // Tıklanan kategoriyi bul ve seç
                withAnimation {
                    secilenKategori = secilenKategori == nil ? "dummy" : nil
                }
            }
        }
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func kategorileriEslestir() -> [KarsilastirmaVeri] {
        var sonuc: [KarsilastirmaVeri] = []
        
        let tumKategoriler = Set(mevcutKategoriler.map { $0.kategoriAdi } + oncekiKategoriler.map { $0.kategoriAdi })
        
        for kategoriAdi in tumKategoriler {
            let mevcutTutar = mevcutKategoriler.first { $0.kategoriAdi == kategoriAdi }?.tutar ?? 0
            let oncekiTutar = oncekiKategoriler.first { $0.kategoriAdi == kategoriAdi }?.tutar ?? 0
            
            sonuc.append(KarsilastirmaVeri(
                kategoriAdi: kategoriAdi,
                mevcutTutar: mevcutTutar,
                oncekiTutar: oncekiTutar
            ))
        }
        
        return sonuc.sorted { $0.mevcutTutar > $1.mevcutTutar }
    }
}

struct KarsilastirmaVeri: Identifiable {
    let id = UUID()
    let kategoriAdi: String
    let mevcutTutar: Double
    let oncekiTutar: Double
}

// Kategori Değişim Satırı
struct KategoriDegisimSatiri: View {
    @EnvironmentObject var appSettings: AppSettings
    let degisim: KategoriDegisim
    
    var body: some View {
        HStack {
            Image(systemName: degisim.ikon)
                .font(.title3)
                .foregroundColor(degisim.renk)
                .frame(width: 30)
            
            VStack(alignment: .leading) {
                Text(LocalizedStringKey(degisim.kategoriAdi))
                    .font(.subheadline)
                
                HStack(spacing: 4) {
                    Text(formatCurrency(
                        amount: abs(degisim.fark),
                        currencyCode: appSettings.currencyCode,
                        localeIdentifier: appSettings.languageCode
                    ))
                    .font(.caption)
                    
                    Text("(\(String(format: "%.1f%%", abs(degisim.yuzde))))")
                        .font(.caption)
                }
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: degisim.fark > 0 ? "arrow.up.right" : "arrow.down.right")
                .font(.caption.bold())
                .foregroundColor(degisim.fark > 0 ? .red : .green)
        }
        .padding(.vertical, 8)
    }
}

// Net Değişim Kartı
struct NetDegisimKarti: View {
    @EnvironmentObject var appSettings: AppSettings
    let mevcutNet: Double
    let oncekiNet: Double
    
    private var fark: Double {
        mevcutNet - oncekiNet
    }
    
    private var iyilesme: Bool {
        mevcutNet > oncekiNet
    }
    
    var body: some View {
        VStack(spacing: 12) {
            Text("detailed_reports.comparison.net_change")
                .font(.headline)
            
            HStack(spacing: 20) {
                VStack(alignment: .leading) {
                    Text("detailed_reports.comparison.current_period")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(formatCurrency(
                        amount: mevcutNet,
                        currencyCode: appSettings.currencyCode,
                        localeIdentifier: appSettings.languageCode
                    ))
                    .font(.title3.bold())
                    .foregroundColor(mevcutNet >= 0 ? .green : .red)
                }
                
                Image(systemName: "arrow.right")
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading) {
                    Text("detailed_reports.comparison.difference")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 4) {
                        Image(systemName: iyilesme ? "arrow.up.right" : "arrow.down.right")
                        Text(formatCurrency(
                            amount: abs(fark),
                            currencyCode: appSettings.currencyCode,
                            localeIdentifier: appSettings.languageCode
                        ))
                    }
                    .font(.title3.bold())
                    .foregroundColor(iyilesme ? .green : .red)
                }
                
                Spacer()
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [
                    iyilesme ? Color.green.opacity(0.1) : Color.red.opacity(0.1),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(12)
    }
}