//
//  HesapHareketleriRaporView.swift
//  Walleo
//
//  Created by Mustafa Turan on 14.07.2025.
//


// Dosya: /Users/mt/Documents/GitHub/Walleo/Walleo/Features/ReportDetailed/HesapHareketleriRaporView.swift

import SwiftUI
import Charts

struct HesapHareketleriRaporView: View {
    @EnvironmentObject var appSettings: AppSettings
    let veri: HesapHareketleriVerisi
    
    @State private var genisletilenHesaplar: Set<UUID> = []
    @State private var animasyonTamamlandi = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Başlık
                baslikView
                
                // Aktivite Liderleri
                aktiviteLiderleri
                
                // Bakiye Değişim Listesi
                bakiyeDegisimListesi
            }
            .padding()
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                animasyonTamamlandi = true
            }
        }
    }
    
    private var baslikView: some View {
        HStack {
            Image(systemName: "building.columns.fill")
                .font(.title2)
                .foregroundColor(.blue)
            
            Text("detailed_reports.account_movements.title")
                .font(.title2.bold())
            
            Spacer()
        }
        .padding(.bottom, 10)
    }
    
    private var aktiviteLiderleri: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("detailed_reports.account_movements.activity_leaders")
                .font(.headline)
            
            HStack(spacing: 12) {
                ForEach(Array(veri.aktiviteLiderleri.prefix(3).enumerated()), id: \.element.hesap.id) { index, lider in
                    aktiviteLiderKarti(lider: lider, sira: index + 1)
                        .opacity(animasyonTamamlandi ? 1 : 0)
                        .offset(y: animasyonTamamlandi ? 0 : 20)
                        .animation(.spring(response: 0.5).delay(Double(index) * 0.1), value: animasyonTamamlandi)
                }
            }
        }
    }
    
    private func aktiviteLiderKarti(lider: HesapAktivitesi, sira: Int) -> some View {
        VStack(spacing: 8) {
            // Madalya
            ZStack {
                Circle()
                    .fill(madalyaRengi(sira: sira))
                    .frame(width: 40, height: 40)
                
                Text("\(sira)")
                    .font(.title3.bold())
                    .foregroundColor(.white)
            }
            
            Text(lider.hesap.isim)
                .font(.caption.bold())
                .lineLimit(1)
            
            Text("\(lider.islemSayisi)")
                .font(.caption2)
                .foregroundColor(.secondary)
                + Text(" ")
                + Text("detailed_reports.account_movements.transactions")
                    .font(.caption2)
                    .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(madalyaRengi(sira: sira).opacity(0.3), lineWidth: 2)
        )
    }
    
    private func madalyaRengi(sira: Int) -> Color {
        switch sira {
        case 1: return .yellow
        case 2: return .gray
        case 3: return Color.orange
        default: return .blue
        }
    }
    
    private var bakiyeDegisimListesi: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("detailed_reports.account_movements.balance_changes")
                .font(.headline)
            
            ForEach(veri.hesapDegisimleri) { degisim in
                hesapDegisimSatiri(degisim: degisim)
            }
        }
    }
    
    private func hesapDegisimSatiri(degisim: HesapDegisimi) -> some View {
        VStack(spacing: 0) {
            // Ana satır
            Button {
                withAnimation(.spring(response: 0.3)) {
                    if genisletilenHesaplar.contains(degisim.hesap.id) {
                        genisletilenHesaplar.remove(degisim.hesap.id)
                    } else {
                        genisletilenHesaplar.insert(degisim.hesap.id)
                    }
                }
            } label: {
                HStack(spacing: 12) {
                    // Hesap ikonu
                    Image(systemName: degisim.hesap.ikonAdi)
                        .font(.title3)
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(degisim.hesap.renk)
                        .cornerRadius(10)
                    
                    // Hesap bilgileri
                    VStack(alignment: .leading, spacing: 4) {
                        Text(degisim.hesap.isim)
                            .font(.subheadline.bold())
                            .foregroundColor(.primary)
                        
                        HStack(spacing: 4) {
                            Text("detailed_reports.account_movements.start_balance")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(formatCurrency(
                                amount: degisim.baslangicBakiyesi,
                                currencyCode: appSettings.currencyCode,
                                localeIdentifier: appSettings.languageCode
                            ))
                            .font(.caption.bold())
                        }
                    }
                    
                    Spacer()
                    
                    // Net değişim ve trend
                    VStack(alignment: .trailing, spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: degisim.netFark >= 0 ? "arrow.up.right" : "arrow.down.right")
                                .font(.caption)
                            
                            Text(formatCurrency(
                                amount: abs(degisim.netFark),
                                currencyCode: appSettings.currencyCode,
                                localeIdentifier: appSettings.languageCode
                            ))
                            .font(.callout.bold())
                        }
                        .foregroundColor(degisim.netFark >= 0 ? .green : .red)
                        
                        // Mini trend grafiği
                        miniTrendGrafigi(trend: degisim.gunlukBakiyeler)
                    }
                    
                    // Genişletme ikonu
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(genisletilenHesaplar.contains(degisim.hesap.id) ? 90 : 0))
                }
                .padding()
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            // Genişletilmiş içerik
            if genisletilenHesaplar.contains(degisim.hesap.id) {
                VStack(spacing: 0) {
                    Divider()
                    
                    // Bitiş bakiyesi
                    HStack {
                        Text("detailed_reports.account_movements.end_balance")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(formatCurrency(
                            amount: degisim.bitisBakiyesi,
                            currencyCode: appSettings.currencyCode,
                            localeIdentifier: appSettings.languageCode
                        ))
                        .font(.subheadline.bold())
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    
                    Divider()
                    
                    // En büyük 5 işlem
                    VStack(alignment: .leading, spacing: 8) {
                        Text("detailed_reports.account_movements.top_transactions")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                        
                        ForEach(degisim.enBuyukIslemler) { islem in
                            miniIslemSatiri(islem: islem)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .transition(.asymmetric(
                    insertion: .push(from: .top).combined(with: .opacity),
                    removal: .push(from: .bottom).combined(with: .opacity)
                ))
            }
        }
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }
    
    private func miniTrendGrafigi(trend: [(tarih: Date, bakiye: Double)]) -> some View {
        Chart(trend, id: \.tarih) { item in
            LineMark(
                x: .value("Tarih", item.tarih),
                y: .value("Bakiye", item.bakiye)
            )
            .foregroundStyle(Color.blue)
            .lineStyle(StrokeStyle(lineWidth: 2))
            
            AreaMark(
                x: .value("Tarih", item.tarih),
                y: .value("Bakiye", item.bakiye)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [Color.blue.opacity(0.3), Color.blue.opacity(0.1)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .chartXScale(domain: trend.first?.tarih ?? Date()...trend.last?.tarih ?? Date())
        .chartYScale(domain: .automatic(includesZero: false))
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .frame(width: 60, height: 30)
    }
    
    private func miniIslemSatiri(islem: Islem) -> some View {
        HStack(spacing: 8) {
            Image(systemName: islem.kategori?.ikonAdi ?? "tag.fill")
                .font(.caption)
                .foregroundColor(islem.kategori?.renk ?? .gray)
                .frame(width: 20, height: 20)
            
            Text(islem.isim)
                .font(.caption)
                .lineLimit(1)
            
            Spacer()
            
            Text(formatCurrency(
                amount: islem.tutar,
                currencyCode: appSettings.currencyCode,
                localeIdentifier: appSettings.languageCode
            ))
            .font(.caption.bold())
            .foregroundColor(islem.tur == .gelir ? .green : .primary)
        }
        .padding(.horizontal)
    }
}