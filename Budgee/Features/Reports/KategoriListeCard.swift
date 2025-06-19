//
//  KategoriListeCard.swift
//  Budgee
//
//  Created by Mustafa Turan on 19.06.2025.
//


import SwiftUI

struct KategoriListeCard: View {
    let baslikKey: LocalizedStringKey
    let kategoriler: [KategoriOzetSatiri]
    
    @EnvironmentObject var appSettings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(baslikKey)
                .font(.headline)
                .foregroundStyle(.secondary)
            
            VStack(spacing: 14) {
                ForEach(kategoriler) { kategori in
                    HStack(spacing: 12) {
                        Image(systemName: kategori.ikonAdi)
                            .font(.callout)
                            .foregroundColor(kategori.renk)
                            .frame(width: 38, height: 38)
                            .background(kategori.renk.opacity(0.15))
                            .cornerRadius(8)
                        
                        Text(LocalizedStringKey(kategori.kategoriAdi))
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(formatCurrency(
                                amount: kategori.tutar,
                                currencyCode: appSettings.currencyCode,
                                localeIdentifier: appSettings.languageCode
                            ))
                            .font(.callout.bold())
                            .foregroundStyle(.primary)
                            
                            Text(String(format: "%.1f%%", kategori.yuzde))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    if kategori.id != kategoriler.last?.id {
                        Divider().padding(.leading, 50)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, y: 5)
    }
}