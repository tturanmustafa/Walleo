//
//  NakitAkisiAnaMetriklerView.swift
//  Walleo
//
//  Created by Mustafa Turan on 18.07.2025.
//


// Walleo/Features/ReportsDetailed/NakitAkisi/Views/NakitAkisiAnaMetriklerView.swift

import SwiftUI

struct NakitAkisiAnaMetriklerView: View {
    let rapor: NakitAkisiRaporu
    @EnvironmentObject var appSettings: AppSettings
    
    var body: some View {
        VStack(spacing: 20) {
            // Net akış kartı
            netAkisKarti
            
            // Gelir ve gider kartları
            HStack(spacing: 16) {
                gelirKarti
                giderKarti
            }
        }
    }
    
    @ViewBuilder
    private var netAkisKarti: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: rapor.netAkis >= 0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                    .font(.title)
                    .foregroundColor(rapor.netAkis >= 0 ? .green : .red)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("cashflow.net_flow")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text(formatCurrency(
                        amount: abs(rapor.netAkis),
                        currencyCode: appSettings.currencyCode,
                        localeIdentifier: appSettings.languageCode
                    ))
                    .font(.title.bold())
                    .foregroundColor(rapor.netAkis >= 0 ? .green : .red)
                }
                
                Spacer()
                
                // Yüzdelik değişim
                if rapor.toplamGelir > 0 {
                    VStack(alignment: .trailing, spacing: 2) {
                        let yuzde = (rapor.netAkis / rapor.toplamGelir) * 100
                        Text(String(format: "%+.1f%%", yuzde))
                            .font(.headline)
                            .foregroundColor(yuzde >= 0 ? .green : .red)
                        
                        Text("cashflow.of_income")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            // Özet çubuk
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.1))
                        .frame(height: 8)
                    
                    if rapor.toplamGelir > 0 || rapor.toplamGider > 0 {
                        let total = rapor.toplamGelir + rapor.toplamGider
                        let gelirGenislik = (rapor.toplamGelir / total) * geometry.size.width
                        
                        HStack(spacing: 0) {
                            Rectangle()
                                .fill(Color.green)
                                .frame(width: gelirGenislik, height: 8)
                            
                            Rectangle()
                                .fill(Color.red)
                                .frame(height: 8)
                        }
                        .cornerRadius(4)
                    }
                }
            }
            .frame(height: 8)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
    
    @ViewBuilder
    private var gelirKarti: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundColor(.green)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("common.income")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text(formatCurrency(
                        amount: rapor.toplamGelir,
                        currencyCode: appSettings.currencyCode,
                        localeIdentifier: appSettings.languageCode
                    ))
                    .font(.headline.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                }
                
                Spacer()
            }
            
            // Günlük ortalama
            HStack {
                Text("cashflow.daily_avg")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                let gunSayisi = Calendar.current.dateComponents([.day], from: rapor.baslangicTarihi, to: rapor.bitisTarihi).day ?? 1
                Text(formatCurrency(
                    amount: rapor.toplamGelir / Double(gunSayisi),
                    currencyCode: appSettings.currencyCode,
                    localeIdentifier: appSettings.languageCode
                ))
                .font(.caption.bold())
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.green.opacity(0.1))
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private var giderKarti: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.title2)
                    .foregroundColor(.red)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("common.expense")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text(formatCurrency(
                        amount: rapor.toplamGider,
                        currencyCode: appSettings.currencyCode,
                        localeIdentifier: appSettings.languageCode
                    ))
                    .font(.headline.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                }
                
                Spacer()
            }
            
            // Günlük ortalama
            HStack {
                Text("cashflow.daily_avg")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                let gunSayisi = Calendar.current.dateComponents([.day], from: rapor.baslangicTarihi, to: rapor.bitisTarihi).day ?? 1
                Text(formatCurrency(
                    amount: rapor.toplamGider / Double(gunSayisi),
                    currencyCode: appSettings.currencyCode,
                    localeIdentifier: appSettings.languageCode
                ))
                .font(.caption.bold())
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.red.opacity(0.1))
        .cornerRadius(12)
    }
}