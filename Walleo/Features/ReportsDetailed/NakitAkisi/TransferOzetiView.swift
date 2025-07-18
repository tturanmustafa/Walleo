//
//  TransferOzetiView.swift
//  Walleo
//
//  Created by Mustafa Turan on 18.07.2025.
//


// Walleo/Features/ReportsDetailed/NakitAkisi/Views/TransferOzetiView.swift

import SwiftUI

struct TransferOzetiView: View {
    let ozet: TransferOzeti
    @EnvironmentObject var appSettings: AppSettings
    @State private var detaylariGoster = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Başlık
            HStack {
                Image(systemName: "arrow.left.arrow.right.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("cashflow.transfers")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    Text("\(ozet.toplamTransferSayisi) transfer")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Text(formatCurrency(
                    amount: ozet.toplamTransferTutari,
                    currencyCode: appSettings.currencyCode,
                    localeIdentifier: appSettings.languageCode
                ))
                .font(.headline.bold())
            }
            
            // En sık transfer
            if let enSik = ozet.enSikTransferYapilan {
                HStack {
                    Text("cashflow.most_frequent_transfer")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Text(enSik.kaynak?.isim ?? "")
                            .font(.caption)
                            .fontWeight(.medium)
                        
                        Image(systemName: "arrow.right")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        
                        Text(enSik.hedef?.isim ?? "")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }
            }
            
            // Detayları göster butonu
            Button(action: { withAnimation { detaylariGoster.toggle() } }) {
                HStack {
                    Text(detaylariGoster ? "cashflow.hide_details" : "cashflow.show_details")
                        .font(.caption)
                    
                    Image(systemName: detaylariGoster ? "chevron.up" : "chevron.down")
                        .font(.caption)
                }
            }
            .foregroundColor(.accentColor)
            
            // Detaylar
            if detaylariGoster {
                VStack(spacing: 8) {
                    ForEach(ozet.transferDetaylari.prefix(5)) { detay in
                        transferDetaySatiri(detay: detay)
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
    
    @ViewBuilder
    private func transferDetaySatiri(detay: TransferOzeti.TransferDetay) -> some View {
        HStack {
            // Kaynak hesap
            HStack(spacing: 6) {
                Image(systemName: detay.kaynakHesap.ikonAdi)
                    .font(.caption)
                    .foregroundColor(detay.kaynakHesap.renk)
                
                Text(detay.kaynakHesap.isim)
                    .font(.caption)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            
            // Ok
            Image(systemName: "arrow.right")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 20)
            
            // Hedef hesap
            HStack(spacing: 6) {
                Text(detay.hedefHesap.isim)
                    .font(.caption)
                    .lineLimit(1)
                
                Image(systemName: detay.hedefHesap.ikonAdi)
                    .font(.caption)
                    .foregroundColor(detay.hedefHesap.renk)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Tutar ve sayı
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatCurrency(
                    amount: detay.toplamTutar,
                    currencyCode: appSettings.currencyCode,
                    localeIdentifier: appSettings.languageCode
                ))
                .font(.caption.bold())
                
                Text("\(detay.islemSayisi)x")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}