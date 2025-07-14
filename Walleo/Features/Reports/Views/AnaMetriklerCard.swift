//
//  AnaMetriklerCard.swift
//  Budgee
//
//  Created by Mustafa Turan on 19.06.2025.
//


import SwiftUI

struct AnaMetriklerCard: View {
    let ozetVerisi: OzetVerisi
    @EnvironmentObject var appSettings: AppSettings
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Kart Başlığı
            Text(LocalizedStringKey("reports.summary.card.main_metrics"))
                .font(.headline)
                .foregroundStyle(.secondary)
            
            // Net Akış (En Önemli Metrik)
            VStack {
                Text(formatCurrency(
                    amount: ozetVerisi.netAkis,
                    currencyCode: appSettings.currencyCode,
                    localeIdentifier: appSettings.languageCode
                ))
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(ozetVerisi.netAkis >= 0 ? .green : .red)
                
                Text(LocalizedStringKey("reports.summary.net_flow"))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            
            // Gelir ve Gider Metrikleri
            HStack(spacing: 16) {
                MetrikView(
                    baslikKey: "common.income",
                    tutar: ozetVerisi.toplamGelir,
                    renk: .green
                )
                
                Divider()
                
                MetrikView(
                    baslikKey: "common.expense",
                    tutar: ozetVerisi.toplamGider,
                    renk: .red
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, y: 5)
    }
}

// AnaMetriklerCard içindeki küçük metrik görünümleri için yardımcı View
private struct MetrikView: View {
    let baslikKey: LocalizedStringKey
    let tutar: Double
    let renk: Color
    @EnvironmentObject var appSettings: AppSettings

    var body: some View {
        HStack {
            Circle()
                .fill(renk)
                .frame(width: 8, height: 8)
            
            VStack(alignment: .leading) {
                Text(baslikKey)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                
                Text(formatCurrency(
                    amount: tutar,
                    currencyCode: appSettings.currencyCode,
                    localeIdentifier: appSettings.languageCode
                ))
                .font(.title3.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            }
            Spacer()
        }
    }
}