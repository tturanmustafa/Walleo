//
//  ProjeksiyonOzetiView.swift
//  Walleo
//
//  Created by Mustafa Turan on 18.07.2025.
//


// Walleo/Features/ReportsDetailed/NakitAkisi/Views/ProjeksiyonView.swift

import SwiftUI
import Charts

// Projeksiyon Özeti
struct ProjeksiyonOzetiView: View {
    let projeksiyon: GelecekProjeksiyonu
    @EnvironmentObject var appSettings: AppSettings
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("cashflow.projection.title")
                        .font(.headline)
                    
                    Text(String(format: NSLocalizedString("cashflow.projection.days", comment: ""), projeksiyon.projeksiyonSuresi))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            
            // Özet metrikler
            HStack(spacing: 16) {
                ozetKart(
                    baslik: "cashflow.projection.income",
                    tutar: projeksiyon.tahminiGelir,
                    ikon: "arrow.up.circle",
                    renk: .green
                )
                
                ozetKart(
                    baslik: "cashflow.projection.expense",
                    tutar: projeksiyon.tahminiGider,
                    ikon: "arrow.down.circle",
                    renk: .red
                )
                
                ozetKart(
                    baslik: "cashflow.projection.net",
                    tutar: projeksiyon.tahminiNetAkis,
                    ikon: projeksiyon.tahminiNetAkis >= 0 ? "checkmark.circle" : "exclamationmark.circle",
                    renk: projeksiyon.tahminiNetAkis >= 0 ? .green : .red
                )
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
    
    @ViewBuilder
    private func ozetKart(baslik: String, tutar: Double, ikon: String, renk: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: ikon)
                .font(.title3)
                .foregroundColor(renk)
            
            Text(LocalizedStringKey(baslik))
                .font(.caption2)
                .foregroundStyle(.secondary)
            
            Text(formatCurrency(
                amount: tutar,
                currencyCode: appSettings.currencyCode,
                localeIdentifier: appSettings.languageCode
            ))
            .font(.caption.bold())
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color(.tertiarySystemGroupedBackground))
        .cornerRadius(8)
    }
}

// Projeksiyon Grafiği
struct ProjeksiyonGrafigiView: View {
    let projeksiyon: GelecekProjeksiyonu
    @EnvironmentObject var appSettings: AppSettings
    @State private var secilenTarih: Date?
    
    private var secilenGun: GelecekProjeksiyonu.GunlukProjeksiyon? {
        guard let tarih = secilenTarih else { return nil }
        return projeksiyon.gunlukProjeksiyon.min(by: {
            abs($0.tarih.timeIntervalSince(tarih)) < abs($1.tarih.timeIntervalSince(tarih))
        })
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("cashflow.projection.chart")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            // Seçilen gün detayı
            if let gun = secilenGun {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(gun.tarih, style: .date)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Text(formatCurrency(
                            amount: gun.tahminiKumulatifBakiye,
                            currencyCode: appSettings.currencyCode,
                            localeIdentifier: appSettings.languageCode
                        ))
                        .font(.headline.bold())
                        .foregroundColor(gun.tahminiKumulatifBakiye >= 0 ? .primary : .red)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 16) {
                        VStack(alignment: .trailing, spacing: 2) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.up")
                                    .font(.caption2)
                                    .foregroundColor(.green)
                                Text(formatCurrency(
                                    amount: gun.tahminiGelir,
                                    currencyCode: appSettings.currencyCode,
                                    localeIdentifier: appSettings.languageCode
                                ))
                                .font(.caption)
                            }
                            
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.down")
                                    .font(.caption2)
                                    .foregroundColor(.red)
                                Text(formatCurrency(
                                    amount: gun.tahminiGider,
                                    currencyCode: appSettings.currencyCode,
                                    localeIdentifier: appSettings.languageCode
                                ))
                                .font(.caption)
                            }
                        }
                    }
                }
                .padding()
                .background(Color(.tertiarySystemGroupedBackground))
                .cornerRadius(12)
                .transition(.asymmetric(
                    insertion: .scale.combined(with: .opacity),
                    removal: .scale.combined(with: .opacity)
                ))
            }
            
            // Grafik
            Chart(projeksiyon.gunlukProjeksiyon) { gun in
                LineMark(
                    x: .value("Tarih", gun.tarih, unit: .day),
                    y: .value("Bakiye", gun.tahminiKumulatifBakiye)
                )
                .foregroundStyle(gun.tahminiKumulatifBakiye >= 0 ? Color.blue : Color.red)
                .interpolationMethod(.catmullRom)
                
                AreaMark(
                    x: .value("Tarih", gun.tarih, unit: .day),
                    y: .value("Bakiye", gun.tahminiKumulatifBakiye)
                )
                .foregroundStyle(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            gun.tahminiKumulatifBakiye >= 0 ? Color.blue.opacity(0.3) : Color.red.opacity(0.3),
                            .clear
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)
                
                // Sıfır çizgisi
                RuleMark(y: .value("Sıfır", 0))
                    .foregroundStyle(Color.gray.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
            }
            .frame(height: 200)
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
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
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

// Risk Analizi
struct RiskAnaliziView: View {
    let projeksiyon: GelecekProjeksiyonu
    @EnvironmentObject var appSettings: AppSettings
    
    private var riskMesaji: String {
        switch projeksiyon.riskSeviyesi {
        case .dusuk:
            return "cashflow.risk.low_message"
        case .orta:
            return "cashflow.risk.medium_message"
        case .yuksek:
            return "cashflow.risk.high_message"
        }
    }
    
    private var oneriler: [String] {
        switch projeksiyon.riskSeviyesi {
        case .dusuk:
            return [
                "cashflow.suggestion.low_1",
                "cashflow.suggestion.low_2"
            ]
        case .orta:
            return [
                "cashflow.suggestion.medium_1",
                "cashflow.suggestion.medium_2",
                "cashflow.suggestion.medium_3"
            ]
        case .yuksek:
            return [
                "cashflow.suggestion.high_1",
                "cashflow.suggestion.high_2",
                "cashflow.suggestion.high_3"
            ]
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Risk seviyesi başlığı
            HStack {
                Image(systemName: riskIkonu)
                    .font(.title2)
                    .foregroundColor(projeksiyon.riskSeviyesi.renk)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("cashflow.risk.analysis")
                        .font(.headline)
                    
                    Text(LocalizedStringKey(projeksiyon.riskSeviyesi.mesaj))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(projeksiyon.riskSeviyesi.renk)
                }
                
                Spacer()
            }
            
            // Risk mesajı
            Text(LocalizedStringKey(riskMesaji))
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding()
                .background(Color(.tertiarySystemGroupedBackground))
                .cornerRadius(12)
            
            // Öneriler
            VStack(alignment: .leading, spacing: 12) {
                Text("cashflow.suggestions")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                ForEach(oneriler, id: \.self) { oneri in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "lightbulb.fill")
                            .font(.caption)
                            .foregroundColor(.yellow)
                            .frame(width: 20)
                        
                        Text(LocalizedStringKey(oneri))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
    
    private var riskIkonu: String {
        switch projeksiyon.riskSeviyesi {
        case .dusuk: return "checkmark.shield.fill"
        case .orta: return "exclamationmark.shield.fill"
        case .yuksek: return "xmark.shield.fill"
        }
    }
}