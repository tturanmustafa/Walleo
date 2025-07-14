//
//  PeriyodikKarsilastirmaView.swift
//  Walleo
//
//  Created by Mustafa Turan on 15.07.2025.
//


// >> YENİ DOSYA: Features/ReportsDetailed/Views/PeriyodikKarsilastirmaView.swift

import SwiftUI
import Charts

struct PeriyodikKarsilastirmaView: View {
    let veriler: [HarcamaKarsilastirmaVerisi]
    @EnvironmentObject var appSettings: AppSettings
    
    @State private var secilenVeri: HarcamaKarsilastirmaVerisi?
    
    private var ortalamaDeger: Double {
        guard !veriler.isEmpty else { return 0 }
        return veriler.reduce(0) { $0 + $1.deger } / Double(veriler.count)
    }
    
    var body: some View {
        VStack(spacing: 12) {
            Text("reports.heatmap.comparison")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            if veriler.isEmpty {
                ContentUnavailableView(
                    "Karşılaştırma verisi yok",
                    systemImage: "chart.bar.fill"
                )
                .frame(height: 120)
            } else {
                Chart(veriler) { veri in
                    BarMark(
                        x: .value("Periyot", veri.localizationKey != nil 
                            ? NSLocalizedString(veri.localizationKey!, comment: "") 
                            : veri.etiket),
                        y: .value("Tutar", veri.deger)
                    )
                    .foregroundStyle(
                        secilenVeri?.id == veri.id ? Color.accentColor : veri.renk
                    )
                    .cornerRadius(4)
                    .annotation(position: .top) {
                        if secilenVeri?.id == veri.id {
                            Text(formatCurrency(
                                amount: veri.deger,
                                currencyCode: appSettings.currencyCode,
                                localeIdentifier: appSettings.languageCode
                            ))
                            .font(.caption)
                            .fontWeight(.bold)
                            .padding(4)
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(4)
                        }
                    }
                    
                    // Ortalama çizgisi
                    RuleMark(y: .value("Ortalama", ortalamaDeger))
                        .foregroundStyle(.gray.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))
                }
                .frame(height: 120)
                .chartXAxis {
                    AxisMarks { value in
                        AxisValueLabel()
                            .font(.caption)
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let doubleValue = value.as(Double.self) {
                                Text(formatCurrency(
                                    amount: doubleValue,
                                    currencyCode: appSettings.currencyCode,
                                    localeIdentifier: appSettings.languageCode
                                ))
                                .font(.caption2)
                            }
                        }
                    }
                }
                .onTapGesture { location in
                    // Chart üzerinde tıklama algılama
                    withAnimation(.spring(response: 0.3)) {
                        // Basit bir toggle mantığı
                        if secilenVeri != nil {
                            secilenVeri = nil
                        } else if let ilkVeri = veriler.first {
                            secilenVeri = ilkVeri
                        }
                    }
                }
                
                // Özet bilgi
                if !veriler.isEmpty {
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("En Yüksek")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            if let maxVeri = veriler.max(by: { $0.deger < $1.deger }) {
                                Text(maxVeri.localizationKey != nil 
                                    ? NSLocalizedString(maxVeri.localizationKey!, comment: "") 
                                    : maxVeri.etiket)
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Ortalama")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(formatCurrency(
                                amount: ortalamaDeger,
                                currencyCode: appSettings.currencyCode,
                                localeIdentifier: appSettings.languageCode
                            ))
                            .font(.caption)
                            .fontWeight(.medium)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
}
