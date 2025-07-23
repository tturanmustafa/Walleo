//
//  IslemTipiKartlariView.swift
//  Walleo
//
//  Created by Mustafa Turan on 23.07.2025.
//


// Walleo/Features/ReportsDetailed/NakitAkisi/Views/IslemTipiKartlariView.swift

import SwiftUI

struct IslemTipiKartlariView: View {
    let dagilim: IslemTipiDagilimi
    @EnvironmentObject var appSettings: AppSettings
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("cashflow.transaction_type_distribution")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            // Kartlar
            VStack(spacing: 12) {
                islemTipiKarti(baslik: "cashflow.normal_transactions", ikon: "arrow.right.circle.fill", ozet: dagilim.normalIslemler, renk: .blue)
                islemTipiKarti(baslik: "cashflow.installment_transactions", ikon: "creditcard.viewfinder", ozet: dagilim.taksitliIslemler, renk: .orange)
                islemTipiKarti(baslik: "cashflow.recurring_transactions", ikon: "arrow.clockwise.circle.fill", ozet: dagilim.tekrarliIslemler, renk: .purple)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
    
    @ViewBuilder
    private func islemTipiKarti(baslik: String, ikon: String, ozet: IslemTipiDagilimi.IslemTipiOzet, renk: Color) -> some View {
        VStack(spacing: 0) {
            // Üst kısım - Başlık ve ikon
            HStack(spacing: 12) {
                Image(systemName: ikon)
                    .font(.title2)
                    .foregroundColor(renk)
                    .frame(width: 40, height: 40)
                    .background(renk.opacity(0.15))
                    .cornerRadius(8)
                
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
            .padding()
            
            Divider()
            
            // Alt kısım - Değerler (DÜZELTME BURADA)
            HStack(spacing: 0) {
                // Gelir bölümü
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up")
                            .font(.caption2)
                            .foregroundColor(.green)
                        Text("common.income")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    
                    Text(formatCurrency(
                        amount: ozet.toplamGelir, 
                        currencyCode: appSettings.currencyCode, 
                        localeIdentifier: appSettings.languageCode
                    ))
                    .font(.caption.bold())
                    .foregroundColor(.green)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity)
                
                // Ayırıcı çizgi
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 1, height: 40)
                
                // Gider bölümü
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down")
                            .font(.caption2)
                            .foregroundColor(.red)
                        Text("common.expense")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    
                    Text(formatCurrency(
                        amount: ozet.toplamGider, 
                        currencyCode: appSettings.currencyCode, 
                        localeIdentifier: appSettings.languageCode
                    ))
                    .font(.caption.bold())
                    .foregroundColor(.red)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity)
                
                // Ayırıcı çizgi
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 1, height: 40)
                
                // Net bölümü
                VStack(spacing: 4) {
                    Text("common.net")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    
                    Text(formatCurrency(
                        amount: ozet.netEtki, 
                        currencyCode: appSettings.currencyCode, 
                        localeIdentifier: appSettings.languageCode
                    ))
                    .font(.caption.bold())
                    .foregroundColor(ozet.netEtki >= 0 ? .green : .red)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity)
            }
            .padding()
        }
        .background(Color(.tertiarySystemGroupedBackground))
        .cornerRadius(12)
    }
}