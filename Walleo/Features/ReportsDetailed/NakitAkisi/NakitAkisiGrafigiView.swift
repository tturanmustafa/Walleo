//
//  NakitAkisiGrafigiView.swift
//  Walleo
//
//  Created by Mustafa Turan on 18.07.2025.
//


// Walleo/Features/ReportsDetailed/NakitAkisi/Views/NakitAkisiGrafigiView.swift

import SwiftUI
import Charts

struct NakitAkisiGrafigiView: View {
    let gunlukVeriler: [GunlukNakitAkisi]
    @EnvironmentObject var appSettings: AppSettings
    @State private var secilenTarih: Date?
    @State private var grafikTipi: GrafikTipi = .netAkis
    
    enum GrafikTipi: String, CaseIterable {
        case netAkis = "cashflow.net_flow"
        case kumulatif = "cashflow.cumulative"
        case gelirGider = "cashflow.income_expense"
        case detayli = "cashflow.detailed"
    }
    
    private var secilenVeri: GunlukNakitAkisi? {
        guard let tarih = secilenTarih else { return nil }
        return gunlukVeriler.min(by: { 
            abs($0.tarih.timeIntervalSince(tarih)) < abs($1.tarih.timeIntervalSince(tarih)) 
        })
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Başlık ve grafik tipi seçici
            HStack {
                Text("cashflow.flow_chart")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Menu {
                    ForEach(GrafikTipi.allCases, id: \.self) { tip in
                        Button(action: { 
                            withAnimation(.spring(response: 0.3)) {
                                grafikTipi = tip 
                            }
                        }) {
                            Label(
                                LocalizedStringKey(tip.rawValue),
                                systemImage: grafikTipIkonu(tip)
                            )
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: grafikTipIkonu(grafikTipi))
                            .font(.caption)
                        Text(LocalizedStringKey(grafikTipi.rawValue))
                            .font(.caption)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            
            // Seçilen veri detayı
            if let veri = secilenVeri {
                secilenVeriDetayi(veri: veri)
            }
            
            // Grafik
            Chart {
                switch grafikTipi {
                case .netAkis:
                    netAkisGrafigi
                case .kumulatif:
                    kumulatifGrafik
                case .gelirGider:
                    gelirGiderGrafik
                case .detayli:
                    detayliGrafik
                }
            }
            .frame(height: 250)
            .chartXSelection(value: $secilenTarih)
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let doubleValue = value.as(Double.self) {
                            Text(formatCompactCurrency(amount: doubleValue))
                                .font(.caption2)
                        }
                    }
                }
            }
            .animation(.spring(response: 0.3), value: grafikTipi)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
    
    // MARK: - Grafik Tipleri
    
    @ChartContentBuilder
    private var netAkisGrafigi: some ChartContent {
        ForEach(gunlukVeriler) { veri in
            BarMark(
                x: .value("Tarih", veri.tarih, unit: .day),
                y: .value("Net Akış", veri.netAkis)
            )
            .foregroundStyle(veri.netAkis >= 0 ? Color.green : Color.red)
            .cornerRadius(4)
            .opacity(secilenVeri?.id == veri.id ? 1.0 : 0.7)
        }
        
        if let veri = secilenVeri {
            RuleMark(x: .value("Seçilen", veri.tarih))
                .foregroundStyle(Color.gray.opacity(0.5))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
        }
    }
    
    @ChartContentBuilder
    private var kumulatifGrafik: some ChartContent {
        ForEach(gunlukVeriler) { veri in
            LineMark(
                x: .value("Tarih", veri.tarih, unit: .day),
                y: .value("Kümülatif", veri.kumulatifBakiye)
            )
            .foregroundStyle(Color.blue)
            .interpolationMethod(.catmullRom)
            
            AreaMark(
                x: .value("Tarih", veri.tarih, unit: .day),
                y: .value("Kümülatif", veri.kumulatifBakiye)
            )
            .foregroundStyle(
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue.opacity(0.3), .clear]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .interpolationMethod(.catmullRom)
        }
        
        if let veri = secilenVeri {
            PointMark(
                x: .value("Seçilen", veri.tarih),
                y: .value("Kümülatif", veri.kumulatifBakiye)
            )
            .symbolSize(150)
            .foregroundStyle(Color.blue)
        }
    }
    
    @ChartContentBuilder
    private var gelirGiderGrafik: some ChartContent {
        ForEach(gunlukVeriler) { veri in
            BarMark(
                x: .value("Tarih", veri.tarih, unit: .day),
                y: .value("Gelir", veri.gelir),
                width: .ratio(0.4)
            )
            .foregroundStyle(Color.green)
            .position(by: .value("Tip", "Gelir"))
            .cornerRadius(2)
            
            BarMark(
                x: .value("Tarih", veri.tarih, unit: .day),
                y: .value("Gider", veri.gider),
                width: .ratio(0.4)
            )
            .foregroundStyle(Color.red)
            .position(by: .value("Tip", "Gider"))
            .cornerRadius(2)
        }
    }
    
    @ChartContentBuilder
    private var detayliGrafik: some ChartContent {
        ForEach(gunlukVeriler) { veri in
            // Normal işlemler
            BarMark(
                x: .value("Tarih", veri.tarih, unit: .day),
                y: .value("Normal Gelir", veri.normalGelir),
                width: .ratio(0.8)
            )
            .foregroundStyle(by: .value("Tip", "Normal Gelir"))
            .position(by: .value("Kategori", "Gelir"))
            
            BarMark(
                x: .value("Tarih", veri.tarih, unit: .day),
                y: .value("Normal Gider", -veri.normalGider),
                width: .ratio(0.8)
            )
            .foregroundStyle(by: .value("Tip", "Normal Gider"))
            .position(by: .value("Kategori", "Gider"))
            
            // Taksitli işlemler
            if veri.taksitliGider > 0 {
                BarMark(
                    x: .value("Tarih", veri.tarih, unit: .day),
                    y: .value("Taksitli Gider", -veri.taksitliGider),
                    width: .ratio(0.8)
                )
                .foregroundStyle(by: .value("Tip", "Taksitli"))
                .position(by: .value("Kategori", "Gider"))
            }
            
            // Tekrarlı işlemler
            if veri.tekrarliGelir > 0 {
                BarMark(
                    x: .value("Tarih", veri.tarih, unit: .day),
                    y: .value("Tekrarlı Gelir", veri.tekrarliGelir),
                    width: .ratio(0.8)
                )
                .foregroundStyle(by: .value("Tip", "Tekrarlı Gelir"))
                .position(by: .value("Kategori", "Gelir"))
            }
            
            if veri.tekrarliGider > 0 {
                BarMark(
                    x: .value("Tarih", veri.tarih, unit: .day),
                    y: .value("Tekrarlı Gider", -veri.tekrarliGider),
                    width: .ratio(0.8)
                )
                .foregroundStyle(by: .value("Tip", "Tekrarlı Gider"))
                .position(by: .value("Kategori", "Gider"))
            }
        }
    }
    
    // MARK: - Yardımcı Fonksiyonlar
    
    private func grafikTipIkonu(_ tip: GrafikTipi) -> String {
        switch tip {
        case .netAkis: return "chart.bar.xaxis"
        case .kumulatif: return "chart.line.uptrend.xyaxis"
        case .gelirGider: return "chart.bar.doc.horizontal"
        case .detayli: return "chart.bar.xaxis.ascending"
        }
    }
    
    @ViewBuilder
    private func secilenVeriDetayi(veri: GunlukNakitAkisi) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(veri.tarih, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Text(formatCurrency(
                    amount: veri.netAkis,
                    currencyCode: appSettings.currencyCode,
                    localeIdentifier: appSettings.languageCode
                ))
                .font(.headline.bold())
                .foregroundColor(veri.netAkis >= 0 ? .green : .red)
            }
            
            Divider()
                .frame(height: 30)
            
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up")
                            .font(.caption2)
                            .foregroundColor(.green)
                        Text(LocalizedStringKey("common.income")) // DÜZELTİLDİ
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Text(formatCurrency(
                        amount: veri.gelir,
                        currencyCode: appSettings.currencyCode,
                        localeIdentifier: appSettings.languageCode
                    ))
                    .font(.caption.bold())
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down")
                            .font(.caption2)
                            .foregroundColor(.red)
                        Text(LocalizedStringKey("common.expense")) // DÜZELTİLDİ
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Text(formatCurrency(
                        amount: veri.gider,
                        currencyCode: appSettings.currencyCode,
                        localeIdentifier: appSettings.languageCode
                    ))
                    .font(.caption.bold())
                }
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.tertiarySystemGroupedBackground))
        .cornerRadius(12)
        .transition(.asymmetric(
            insertion: .scale.combined(with: .opacity),
            removal: .scale.combined(with: .opacity)
        ))
    }
    
    private func formatCompactCurrency(amount: Double) -> String {
        let absAmount = abs(amount)
        let sign = amount < 0 ? "-" : ""
        
        if absAmount >= 1_000_000 {
            return "\(sign)\(String(format: "%.1fM", absAmount / 1_000_000))"
        } else if absAmount >= 1_000 {
            return "\(sign)\(String(format: "%.1fK", absAmount / 1_000))"
        } else {
            return "\(sign)\(Int(absAmount))"
        }
    }
}
