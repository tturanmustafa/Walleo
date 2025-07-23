//
//  KategoriAkisKartiView.swift
//  Walleo
//
//  Created by Mustafa Turan on 18.07.2025.
//


// Walleo/Features/ReportsDetailed/NakitAkisi/Views/KategoriAkisKartiView.swift

import SwiftUI
import Charts

struct KategoriAkisKartiView: View {
    let kategoriAkis: KategoriNakitAkisi
    @EnvironmentObject var appSettings: AppSettings
    @State private var trendGoster = false
    
    var body: some View {
        let languageBundle = Bundle.getLanguageBundle(for: appSettings.languageCode)
        // --- DÜZELTME 1: Metinleri AppSettings'e göre oluştur ---
        let islemSayisiMetni = String(
            format: languageBundle.localizedString(forKey: "reports.transaction_count", value: "", table: nil),
            kategoriAkis.islemSayisi
        )
        let ortalamaTutarMetni = String(
            format: languageBundle.localizedString(forKey: "reports.average_with_amount", value: "", table: nil),
            formatCurrency(amount: kategoriAkis.ortalamaIslemTutari, currencyCode: appSettings.currencyCode, localeIdentifier: appSettings.languageCode)
        )

        return VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: kategoriAkis.kategori.ikonAdi)
                    .font(.title2).foregroundColor(kategoriAkis.kategori.renk)
                    .frame(width: 44, height: 44).background(kategoriAkis.kategori.renk.opacity(0.15)).cornerRadius(10)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(LocalizedStringKey(kategoriAkis.kategori.localizationKey ?? kategoriAkis.kategori.isim))
                        .font(.subheadline).fontWeight(.semibold)
                    
                    // --- DÜZELTME 2: Esnek Arayüz (ViewThatFits) ---
                    // Bu yapı, metinlerin sığmazsa alt alta gelmesini sağlar.
                    ViewThatFits {
                        // Geniş ekran için yatay (HStack)
                        HStack(spacing: 8) {
                            Text(islemSayisiMetni).font(.caption).foregroundStyle(.secondary)
                            Text("•").font(.caption).foregroundStyle(.tertiary)
                            Text(ortalamaTutarMetni).font(.caption).foregroundStyle(.secondary)
                        }
                        
                        // Dar ekran için dikey (VStack)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(islemSayisiMetni).font(.caption).foregroundStyle(.secondary)
                            Text(ortalamaTutarMetni).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    // --- DÜZELTME SONU ---
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(formatCurrency(
                        amount: abs(kategoriAkis.toplamTutar),
                        currencyCode: appSettings.currencyCode,
                        localeIdentifier: appSettings.languageCode
                    )).font(.headline.bold()).foregroundColor(kategoriAkis.kategori.tur == .gelir ? .green : .red)
                    
                    if kategoriAkis.kategori.tur == .gelir {
                        Label(LocalizedStringKey("common.income"), systemImage: "arrow.up").font(.caption2).foregroundColor(.green)
                    } else {
                        Label(LocalizedStringKey("common.expense"), systemImage: "arrow.down").font(.caption2).foregroundColor(.red)
                    }
                }
            }
            .padding()
            
            // Trend butonu
            Button(action: { withAnimation { trendGoster.toggle() } }) {
                HStack {
                    Text(trendGoster ? "cashflow.hide_trend" : "cashflow.show_trend")
                        .font(.caption)
                    
                    Spacer()
                    
                    Image(systemName: trendGoster ? "chevron.up" : "chevron.down")
                        .font(.caption)
                }
                .foregroundColor(.accentColor)
                .padding(.horizontal)
                .padding(.bottom, 12)
            }
            
            // Trend grafiği
            if trendGoster {
                VStack(spacing: 12) {
                    Divider()
                    
                    // Mini trend grafiği
                    if !kategoriAkis.akisTrendi.isEmpty {
                        Chart(kategoriAkis.akisTrendi) { nokta in
                            LineMark(
                                x: .value("Tarih", nokta.tarih, unit: .day),
                                y: .value("Tutar", nokta.tutar)
                            )
                            .foregroundStyle(kategoriAkis.kategori.renk)
                            .interpolationMethod(.catmullRom)
                            
                            AreaMark(
                                x: .value("Tarih", nokta.tarih, unit: .day),
                                y: .value("Tutar", nokta.tutar)
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        kategoriAkis.kategori.renk.opacity(0.3),
                                        .clear
                                    ]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .interpolationMethod(.catmullRom)
                        }
                        .frame(height: 60)
                        .chartXAxis(.hidden)
                        .chartYAxis(.hidden)
                        .padding(.horizontal)
                    }
                    
                    // En büyük işlem
                    if let enBuyukIslem = kategoriAkis.enBuyukIslem {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("cashflow.largest_transaction")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                
                                Text(enBuyukIslem.isim)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .lineLimit(1)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(formatCurrency(
                                    amount: enBuyukIslem.tutar,
                                    currencyCode: appSettings.currencyCode,
                                    localeIdentifier: appSettings.languageCode
                                ))
                                .font(.caption.bold())
                                
                                Text(enBuyukIslem.tarih, style: .date)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    Spacer(minLength: 12)
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
}

// Kategori akış grafiği
struct KategoriAkisGrafigiView: View {
    let kategoriler: [KategoriNakitAkisi]
    @EnvironmentObject var appSettings: AppSettings
    
    private var gelirKategorileri: [KategoriNakitAkisi] {
        kategoriler.filter { $0.kategori.tur == .gelir }
    }

    private var giderKategorileri: [KategoriNakitAkisi] {
        kategoriler.filter { $0.kategori.tur == .gider }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("cashflow.category_flow")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            ScrollView {
                VStack(spacing: 16) {
                    // Gelir kategorileri
                    if !gelirKategorileri.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("common.income")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.green)
                            
                            ForEach(gelirKategorileri) { kategori in
                                kategoriSatiri(kategori: kategori)
                            }
                        }
                    }
                    
                    if !gelirKategorileri.isEmpty && !giderKategorileri.isEmpty {
                        Divider()
                    }
                    
                    // Gider kategorileri
                    if !giderKategorileri.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("common.expense")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.red)
                            
                            ForEach(giderKategorileri) { kategori in
                                kategoriSatiri(kategori: kategori)
                            }
                        }
                    }
                }
            }
            .frame(maxHeight: 400) // Maksimum yükseklik sınırı
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
    @ViewBuilder
    private func kategoriSatiri(kategori: KategoriNakitAkisi) -> some View {
        HStack(spacing: 8) {
            // İkon
            Image(systemName: kategori.kategori.ikonAdi)
                .font(.caption)
                .foregroundColor(kategori.kategori.renk)
                .frame(width: 24, height: 24)
                .background(kategori.kategori.renk.opacity(0.15))
                .cornerRadius(6)
            
            // Kategori adı - Esnek genişlik
            Text(LocalizedStringKey(kategori.kategori.localizationKey ?? kategori.kategori.isim))
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(minWidth: 60, maxWidth: .infinity, alignment: .leading)
            
            // Tutar - Sabit genişlik ve küçültme
            Text(formatCurrency(
                amount: abs(kategori.toplamTutar),
                currencyCode: appSettings.currencyCode,
                localeIdentifier: appSettings.languageCode
            ))
            .font(.caption.bold())
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(minWidth: 80, alignment: .trailing)
        }
    }
}
