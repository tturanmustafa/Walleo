//
//  AylikHesapOzetiKarti.swift
//  Walleo
//
//  Created by Mustafa Turan on 28.06.2025.
//


// YENİ DOSYA: AylikHesapOzetiKarti.swift

import SwiftUI

struct AylikHesapOzetiKarti: View {
    @EnvironmentObject var appSettings: AppSettings
    let toplamGelir: Double
    let toplamGider: Double

    var body: some View {
        HStack(spacing: 16) {
            OzetSatiri(
                renk: .green,
                baslikKey: "common.income",
                tutar: toplamGelir
            )
            
            Divider().frame(height: 40)
            
            OzetSatiri(
                renk: .red,
                baslikKey: "common.expense",
                tutar: toplamGider
            )
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

private struct OzetSatiri: View {
    @EnvironmentObject var appSettings: AppSettings
    let renk: Color
    let baslikKey: LocalizedStringKey
    let tutar: Double
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Circle().fill(renk).frame(width: 8, height: 8)
                    Text(baslikKey)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Text(formatCurrency(amount: tutar, currencyCode: appSettings.currencyCode, localeIdentifier: appSettings.languageCode))
                    .font(.title2.bold())
                    .foregroundColor(renk)
            }
            Spacer()
        }
    }
}