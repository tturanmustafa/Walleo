//
//  TopKategorilerCard.swift
//  Budgee
//
//  Created by Mustafa Turan on 19.06.2025.
//


import SwiftUI

struct TopKategorilerCard: View {
    let baslikKey: LocalizedStringKey
    let kategoriler: [KategoriOzetSatiri]
    @EnvironmentObject var appSettings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(baslikKey)
                .font(.headline)
                .foregroundStyle(.secondary)
            
            VStack(spacing: 12) {
                ForEach(kategoriler) { kategori in
                    HStack {
                        Image(systemName: kategori.ikonAdi)
                            .font(.callout)
                            .foregroundColor(kategori.renk)
                            .frame(width: 35, height: 35)
                            .background(kategori.renk.opacity(0.15))
                            .cornerRadius(8)
                        
                        Text(LocalizedStringKey(kategori.kategoriAdi))
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text(formatCurrency(
                                amount: kategori.tutar,
                                currencyCode: appSettings.currencyCode,
                                localeIdentifier: appSettings.languageCode
                            ))
                            .font(.callout.bold())
                            
                            Text(String(format: "%.1f%%", kategori.yuzde))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, y: 5)
    }
}