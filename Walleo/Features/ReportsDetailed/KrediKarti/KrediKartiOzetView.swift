//
//  KrediKartiOzetView.swift
//  Walleo
//
//  Created by Mustafa Turan on 15.07.2025.
//


// >> YENİ DOSYA: Features/ReportsDetailed/Views/KrediKartiOzetView.swift

import SwiftUI
import Charts

struct KrediKartiOzetView: View {
    let genelOzet: KrediKartiGenelOzet
    let kartRaporlari: [KartDetayRaporu]
    @Binding var secilenKartID: UUID?
    @EnvironmentObject var appSettings: AppSettings
    
    @State private var animasyonBasladi = false
    @Namespace private var animation
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 3D Limit Göstergesi
                ThreeDLimitGauge(
                    kullanilmis: genelOzet.toplamHarcama,
                    limit: genelOzet.toplamLimit
                )
                .padding(.top)
                
                // Genel İstatistikler
                HStack(spacing: 16) {
                    StatistikKarti(
                        ikon: "creditcard.fill",
                        baslikKey: "reports.credit_card.total_cards",
                        deger: "\(kartRaporlari.count)",
                        renk: .blue
                    )
                    
                    StatistikKarti(
                        ikon: "arrow.up.circle.fill",
                        baslikKey: "reports.credit_card.total_spending",
                        deger: formatCurrency(
                            amount: genelOzet.toplamHarcama,
                            currencyCode: appSettings.currencyCode,
                            localeIdentifier: appSettings.languageCode
                        ),
                        renk: .red
                    )
                }
                .padding(.horizontal)
                
                // Kart Listesi
                VStack(alignment: .leading, spacing: 12) {
                    Text(LocalizedStringKey("reports.credit_card.cards_overview"))
                        .font(.headline)
                        .padding(.horizontal)
                    
                    ForEach(kartRaporlari) { rapor in
                        KartOzetKarti(
                            rapor: rapor,
                            isSelected: secilenKartID == rapor.id,
                            namespace: animation
                        )
                        .onTapGesture {
                            withAnimation(.spring(response: 0.4)) {
                                secilenKartID = rapor.id
                            }
                        }
                    }
                }
                
                // En yüksek harcama
                if let enYuksek = genelOzet.enYuksekHarcama {
                    EnYuksekHarcamaKarti(islem: enYuksek)
                        .padding(.horizontal)
                }
            }
            .padding(.bottom)
        }
    }
}

// 3D Limit Göstergesi
struct ThreeDLimitGauge: View {
    let kullanilmis: Double
    let limit: Double
    @State private var animasyonTamamlandi = false
    @EnvironmentObject var appSettings: AppSettings
    
    private var kullanimOrani: Double {
        guard limit > 0 else { return 0 }
        return min(kullanilmis / limit, 1.0)
    }
    
    var body: some View {
        ZStack {
            // Gölge efekti için arka plan
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.black.opacity(0.1), Color.clear],
                        center: .center,
                        startRadius: 100,
                        endRadius: 150
                    )
                )
                .frame(width: 300, height: 300)
                .offset(y: 20)
            
            // Ana gösterge
            ZStack {
                // Arka plan halka
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 35)
                    .frame(width: 250, height: 250)
                    .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 5)
                
                // Kullanım göstergesi
                Circle()
                    .trim(from: 0, to: animasyonTamamlandi ? kullanimOrani : 0)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: gradientColors),
                            center: .center,
                            startAngle: .degrees(0),
                            endAngle: .degrees(360 * kullanimOrani)
                        ),
                        style: StrokeStyle(lineWidth: 35, lineCap: .round)
                    )
                    .frame(width: 250, height: 250)
                    .rotationEffect(.degrees(-90))
                    .shadow(color: currentColor.opacity(0.5), radius: 10)
                    .animation(.spring(response: 1.5, dampingFraction: 0.8), value: animasyonTamamlandi)
                
                // Merkez bilgi
                VStack(spacing: 8) {
                    Text("\(Int(kullanimOrani * 100))%")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundColor(currentColor)
                    
                    Text(LocalizedStringKey("reports.credit_card.used"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    VStack(spacing: 4) {
                        Text(formatCurrency(
                            amount: kullanilmis,
                            currencyCode: appSettings.currencyCode,
                            localeIdentifier: appSettings.languageCode
                        ))
                        .font(.headline.bold())
                        .foregroundColor(currentColor)
                        
                        Text("/ \(formatCurrency(amount: limit, currencyCode: appSettings.currencyCode, localeIdentifier: appSettings.languageCode))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .rotation3DEffect(
                .degrees(animasyonTamamlandi ? 0 : -30),
                axis: (x: 1, y: 0, z: 0)
            )
        }
        .onAppear {
            withAnimation(.spring(response: 1.0, dampingFraction: 0.8)) {
                animasyonTamamlandi = true
            }
        }
    }
    
    private var gradientColors: [Color] {
        switch kullanimOrani {
        case 0..<0.5: return [.green, .mint]
        case 0.5..<0.8: return [.yellow, .orange]
        default: return [.orange, .red]
        }
    }
    
    private var currentColor: Color {
        switch kullanimOrani {
        case 0..<0.5: return .green
        case 0.5..<0.8: return .orange
        default: return .red
        }
    }
}