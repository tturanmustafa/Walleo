//
//  HesapAkisKartiView.swift
//  Walleo
//
//  Created by Mustafa Turan on 18.07.2025.
//


// Walleo/Features/ReportsDetailed/NakitAkisi/Views/HesapAkisKartiView.swift

import SwiftUI

struct HesapAkisKartiView: View {
    let hesapAkis: HesapNakitAkisi
    @EnvironmentObject var appSettings: AppSettings
    @State private var detaylariGoster = false
    
    private var hesapTipiAciklamasi: String {
        switch hesapAkis.hesap.detay {
        case .cuzdan:
            return "Cüzdan"
        case .krediKarti:
            return "Kredi Kartı"
        case .kredi:
            return "Kredi"
        }
    }
    
    private var netDegisimYuzdesi: Double? {
        guard hesapAkis.baslangicBakiyesi != 0 else { return nil }
        return (hesapAkis.netDegisim / abs(hesapAkis.baslangicBakiyesi)) * 100
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Ana bilgi satırı
            Button(action: { withAnimation { detaylariGoster.toggle() } }) {
                HStack(spacing: 12) {
                    // Hesap ikonu
                    Image(systemName: hesapAkis.hesap.ikonAdi)
                        .font(.title2)
                        .foregroundColor(hesapAkis.hesap.renk)
                        .frame(width: 44, height: 44)
                        .background(hesapAkis.hesap.renk.opacity(0.15))
                        .cornerRadius(10)
                    
                    // Hesap bilgileri
                    VStack(alignment: .leading, spacing: 4) {
                        Text(hesapAkis.hesap.isim)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        HStack(spacing: 8) {
                            Text(hesapTipiAciklamasi)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            if hesapAkis.islemSayisi > 0 {
                                Text("•")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                                
                                Text("\(hesapAkis.islemSayisi) işlem")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Net değişim
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(formatCurrency(
                            amount: abs(hesapAkis.netDegisim),
                            currencyCode: appSettings.currencyCode,
                            localeIdentifier: appSettings.languageCode
                        ))
                        .font(.headline.bold())
                        .foregroundColor(hesapAkis.netDegisim >= 0 ? .green : .red)
                        
                        if let yuzde = netDegisimYuzdesi {
                            Text(String(format: "%+.1f%%", yuzde))
                                .font(.caption2)
                                .foregroundColor(hesapAkis.netDegisim >= 0 ? .green : .red)
                        }
                    }
                    
                    // Genişletme ikonu
                    Image(systemName: detaylariGoster ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            
            // Detaylar
            if detaylariGoster {
                VStack(spacing: 16) {
                    Divider()
                    
                    // Bakiye değişimi
                    HStack(spacing: 12) {
                        bakiyeKarti(
                            baslik: "cashflow.opening_balance",
                            tutar: hesapAkis.baslangicBakiyesi,
                            ikon: "play.circle",
                            renk: .blue
                        )
                        
                        Image(systemName: "arrow.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        bakiyeKarti(
                            baslik: "cashflow.closing_balance",
                            tutar: hesapAkis.donemSonuBakiyesi,
                            ikon: "stop.circle",
                            renk: hesapAkis.donemSonuBakiyesi >= 0 ? .green : .red
                        )
                    }
                    
                    // Giriş ve çıkışlar
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("cashflow.inflows", systemImage: "arrow.down.circle")
                                .font(.caption)
                                .foregroundColor(.green)
                            
                            Text(formatCurrency(
                                amount: hesapAkis.toplamGiris,
                                currencyCode: appSettings.currencyCode,
                                localeIdentifier: appSettings.languageCode
                            ))
                            .font(.subheadline.bold())
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Divider()
                            .frame(height: 40)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Label("cashflow.outflows", systemImage: "arrow.up.circle")
                                .font(.caption)
                                .foregroundColor(.red)
                            
                            Text(formatCurrency(
                                amount: hesapAkis.toplamCikis,
                                currencyCode: appSettings.currencyCode,
                                localeIdentifier: appSettings.languageCode
                            ))
                            .font(.subheadline.bold())
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    // Günlük ortalama
                    HStack {
                        Text("cashflow.daily_average")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        Text(formatCurrency(
                            amount: hesapAkis.gunlukOrtalama,
                            currencyCode: appSettings.currencyCode,
                            localeIdentifier: appSettings.languageCode
                        ))
                        .font(.caption.bold())
                        .foregroundColor(hesapAkis.gunlukOrtalama >= 0 ? .green : .red)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
    
    @ViewBuilder
    private func bakiyeKarti(baslik: String, tutar: Double, ikon: String, renk: Color) -> some View {
        VStack(alignment: .center, spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: ikon)
                    .font(.caption)
                    .foregroundColor(renk)
                
                Text(LocalizedStringKey(baslik))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            Text(formatCurrency(
                amount: tutar,
                currencyCode: appSettings.currencyCode,
                localeIdentifier: appSettings.languageCode
            ))
            .font(.subheadline.bold())
            .foregroundColor(tutar >= 0 ? .primary : .red)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.tertiarySystemGroupedBackground))
        .cornerRadius(8)
    }
}