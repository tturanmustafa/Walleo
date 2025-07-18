//
//  IslemTipiDagilimiView.swift
//  Walleo
//
//  Created by Mustafa Turan on 18.07.2025.
//


// Walleo/Features/ReportsDetailed/NakitAkisi/Views/IslemTipiDagilimiView.swift

import SwiftUI
import Charts

struct IslemTipiDagilimiView: View {
    let dagilim: IslemTipiDagilimi
    @EnvironmentObject var appSettings: AppSettings
    @State private var secilenTip: String?
    
    private var chartData: [(tip: String, gelir: Double, gider: Double, net: Double, yuzde: Double)] {
        [
            ("cashflow.normal_transactions", 
             dagilim.normalIslemler.toplamGelir,
             dagilim.normalIslemler.toplamGider,
             dagilim.normalIslemler.netEtki,
             dagilim.normalIslemler.yuzdePayi),
            ("cashflow.installment_transactions",
             dagilim.taksitliIslemler.toplamGelir,
             dagilim.taksitliIslemler.toplamGider,
             dagilim.taksitliIslemler.netEtki,
             dagilim.taksitliIslemler.yuzdePayi),
            ("cashflow.recurring_transactions",
             dagilim.tekrarliIslemler.toplamGelir,
             dagilim.tekrarliIslemler.toplamGider,
             dagilim.tekrarliIslemler.netEtki,
             dagilim.tekrarliIslemler.yuzdePayi)
        ]
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("cashflow.transaction_type_distribution")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            // Grafik
            Chart {
                ForEach(chartData, id: \.tip) { veri in
                    BarMark(
                        x: .value("Tip", NSLocalizedString(veri.tip, comment: "")),
                        y: .value("Gelir", veri.gelir)
                    )
                    .foregroundStyle(.green)
                    .cornerRadius(4)
                    .opacity(secilenTip == nil || secilenTip == veri.tip ? 1.0 : 0.5)
                    
                    BarMark(
                        x: .value("Tip", NSLocalizedString(veri.tip, comment: "")),
                        y: .value("Gider", -veri.gider)
                    )
                    .foregroundStyle(.red)
                    .cornerRadius(4)
                    .opacity(secilenTip == nil || secilenTip == veri.tip ? 1.0 : 0.5)
                    
                    // Net çizgisi
                    if veri.net != 0 {
                        PointMark(
                            x: .value("Tip", NSLocalizedString(veri.tip, comment: "")),
                            y: .value("Net", veri.net)
                        )
                        .symbolSize(100)
                        .foregroundStyle(veri.net > 0 ? Color.green : Color.red)
                    }
                }
            }
            .frame(height: 200)
            .chartXSelection(value: .constant(secilenTip))
            .onChange(of: secilenTip) { _, newValue in
                withAnimation(.spring(response: 0.3)) {
                    secilenTip = newValue
                }
            }
            
            // Detay kartları
            VStack(spacing: 12) {
                islemTipiKarti(
                    baslik: "cashflow.normal_transactions",
                    ikon: "arrow.right.circle.fill",
                    ozet: dagilim.normalIslemler,
                    renk: .blue
                )
                
                islemTipiKarti(
                    baslik: "cashflow.installment_transactions",
                    ikon: "creditcard.viewfinder",
                    ozet: dagilim.taksitliIslemler,
                    renk: .orange
                )
                
                islemTipiKarti(
                    baslik: "cashflow.recurring_transactions",
                    ikon: "arrow.clockwise.circle.fill",
                    ozet: dagilim.tekrarliIslemler,
                    renk: .purple
                )
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
    
    @ViewBuilder
    private func islemTipiKarti(
        baslik: String,
        ikon: String,
        ozet: IslemTipiDagilimi.IslemTipiOzet,
        renk: Color
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: ikon)
                .font(.title2)
                .foregroundColor(renk)
                .frame(width: 40, height: 40)
                .background(renk.opacity(0.15))
                .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(LocalizedStringKey(baslik))
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text(String(format: "%.1f%%", ozet.yuzdePayi))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.gray.opacity(0.15))
                        .cornerRadius(4)
                }
                
                HStack(spacing: 16) {
                    // Gelir
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up")
                            .font(.caption2)
                            .foregroundColor(.green)
                        Text(formatCurrency(
                            amount: ozet.toplamGelir,
                            currencyCode: appSettings.currencyCode,
                            localeIdentifier: appSettings.languageCode
                        ))
                        .font(.caption)
                        .foregroundColor(.green)
                    }
                    
                    // Gider
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down")
                            .font(.caption2)
                            .foregroundColor(.red)
                        Text(formatCurrency(
                            amount: ozet.toplamGider,
                            currencyCode: appSettings.currencyCode,
                            localeIdentifier: appSettings.languageCode
                        ))
                        .font(.caption)
                        .foregroundColor(.red)
                    }
                    
                    Spacer()
                    
                    // Net
                    Text(formatCurrency(
                        amount: ozet.netEtki,
                        currencyCode: appSettings.currencyCode,
                        localeIdentifier: appSettings.languageCode
                    ))
                    .font(.caption.bold())
                    .foregroundColor(ozet.netEtki >= 0 ? .green : .red)
                }
            }
        }
        .padding()
        .background(Color(.tertiarySystemGroupedBackground))
        .cornerRadius(12)
    }
}