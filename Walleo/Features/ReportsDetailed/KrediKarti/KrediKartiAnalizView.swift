//
//  KrediKartiAnalizView.swift
//  Walleo
//
//  Created by Mustafa Turan on 15.07.2025.
//


// >> YENİ DOSYA: Features/ReportsDetailed/Views/KrediKartiAnalizView.swift

import SwiftUI
import Charts

struct KrediKartiAnalizView: View {
    let analiz: HarcamaAnalizi
    let icgoruler: [KrediKartiIcgorusu]
    @EnvironmentObject var appSettings: AppSettings
    
    @State private var secilenIcgoru: KrediKartiIcgorusu?
    @State private var animasyonTamamlandi = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Günlük ortalama kart
                GunlukOrtalamaKarti(
                    ortalama: analiz.gunlukOrtalamaHarcama,
                    animasyonTamamlandi: animasyonTamamlandi
                )
                .padding(.horizontal)
                
                // En sık harcama günü analizi
                if let enSikGun = analiz.enSikHarcamaGunu {
                    EnSikHarcamaGunuKarti(
                        gunAnalizi: enSikGun,
                        animasyonTamamlandi: animasyonTamamlandi
                    )
                    .padding(.horizontal)
                }
                
                // Kategori trend radar grafiği
                if !analiz.kategoriTrendleri.isEmpty {
                    KategoriRadarChart(
                        veriler: analiz.kategoriTrendleri,
                        animasyonTamamlandi: animasyonTamamlandi
                    )
                    .frame(height: 300)
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(16)
                    .padding(.horizontal)
                }
                
                // Akıllı içgörüler
                if !icgoruler.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(LocalizedStringKey("reports.credit_card.smart_insights"))
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ForEach(icgoruler) { icgoru in
                            IcgoruKarti(
                                icgoru: icgoru,
                                isExpanded: secilenIcgoru?.id == icgoru.id
                            )
                            .onTapGesture {
                                withAnimation(.spring(response: 0.3)) {
                                    secilenIcgoru = secilenIcgoru?.id == icgoru.id ? nil : icgoru
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
            }
            .padding(.vertical)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                animasyonTamamlandi = true
            }
        }
    }
}

// Günlük ortalama kartı
struct GunlukOrtalamaKarti: View {
    let ortalama: Double
    let animasyonTamamlandi: Bool
    @EnvironmentObject var appSettings: AppSettings
    
    @State private var displayedAmount: Double = 0
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text(LocalizedStringKey("reports.credit_card.daily_average"))
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text(formatCurrency(
                        amount: displayedAmount,
                        currencyCode: appSettings.currencyCode,
                        localeIdentifier: appSettings.languageCode
                    ))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
                }
                
                Spacer()
                
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 40))
                    .foregroundColor(.blue)
                    .rotationEffect(.degrees(animasyonTamamlandi ? 0 : -180))
            }
            
            // Mini grafik
            MiniTrendGrafik(ortalama: ortalama, animasyonTamamlandi: animasyonTamamlandi)
                .frame(height: 60)
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color.blue.opacity(0.1), Color.blue.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
        .onAppear {
            withAnimation(.easeOut(duration: 1.0)) {
                displayedAmount = ortalama
            }
        }
    }
}

// Kategori radar grafiği
struct KategoriRadarChart: View {
    let veriler: [KategoriTrend]
    let animasyonTamamlandi: Bool
    @EnvironmentObject var appSettings: AppSettings
    
    @State private var secilenKategori: KategoriTrend?
    
    var body: some View {
        VStack {
            Text(LocalizedStringKey("reports.credit_card.category_comparison"))
                .font(.headline)
                .padding(.bottom)
            
            GeometryReader { geometry in
                let center = CGPoint(x: geometry.size.width/2, y: geometry.size.height/2)
                let radius = min(geometry.size.width, geometry.size.height) / 2 - 40
                
                ZStack {
                    // Arka plan ızgarası
                    ForEach(1..<6) { level in
                        RadarGrid(
                            center: center,
                            radius: radius * CGFloat(level) / 5,
                            sides: min(veriler.count, 8) // Maksimum 8 kategori
                        )
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    }
                    
                    // Önceki ay
                    if animasyonTamamlandi {
                        RadarShape(
                            values: Array(veriler.prefix(8)).map { $0.oncekiAy },
                            center: center,
                            radius: radius,
                            maxValue: maxValue
                        )
                        .fill(Color.blue.opacity(0.2))
                        .overlay(
                            RadarShape(
                                values: Array(veriler.prefix(8)).map { $0.oncekiAy },
                                center: center,
                                radius: radius,
                                maxValue: maxValue
                            )
                            .stroke(Color.blue, lineWidth: 2)
                        )
                    }
                    
                    // Bu ay
                    RadarShape(
                        values: animasyonTamamlandi ? Array(veriler.prefix(8)).map { $0.buAy } : Array(repeating: 0, count: min(veriler.count, 8)),
                        center: center,
                        radius: radius,
                        maxValue: maxValue
                    )
                    .fill(Color.orange.opacity(0.2))
                    .overlay(
                        RadarShape(
                            values: animasyonTamamlandi ? Array(veriler.prefix(8)).map { $0.buAy } : Array(repeating: 0, count: min(veriler.count, 8)),
                            center: center,
                            radius: radius,
                            maxValue: maxValue
                        )
                        .stroke(Color.orange, lineWidth: 2)
                    )
                    .animation(.spring(response: 0.8), value: animasyonTamamlandi)
                    
                    // Kategori etiketleri
                    ForEach(0..<min(veriler.count, 8), id: \.self) { index in
                        KategoriRadarEtiketi(
                            kategori: veriler[index].kategori,
                            angle: angleForIndex(index, total: min(veriler.count, 8)),
                            radius: radius + 30,
                            center: center,
                            isSelected: secilenKategori?.id == veriler[index].id
                        )
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3)) {
                                secilenKategori = secilenKategori?.id == veriler[index].id ? nil : veriler[index]
                            }
                        }
                    }
                }
                
                // Seçilen kategori detayı
                if let kategori = secilenKategori {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(LocalizedStringKey(kategori.kategori.localizationKey ?? kategori.kategori.isim))
                            .font(.headline)
                        HStack {
                            Label(
                                formatCurrency(amount: kategori.oncekiAy, currencyCode: appSettings.currencyCode, localeIdentifier: appSettings.languageCode),
                                systemImage: "arrow.left"
                            )
                            .foregroundColor(.blue)
                            
                            Image(systemName: kategori.trend.ikon)
                                .foregroundColor(kategori.trend.renk)
                            
                            Label(
                                formatCurrency(amount: kategori.buAy, currencyCode: appSettings.currencyCode, localeIdentifier: appSettings.languageCode),
                                systemImage: "arrow.right"
                            )
                            .foregroundColor(.orange)
                        }
                        .font(.caption)
                    }
                    .padding()
                    .background(Color(.tertiarySystemGroupedBackground))
                    .cornerRadius(8)
                    .position(x: center.x, y: geometry.size.height - 30)
                }
            }
            
            // Açıklama
            HStack(spacing: 20) {
                Label(LocalizedStringKey("reports.credit_card.previous_month"), systemImage: "circle.fill")
                    .foregroundColor(.blue)
                    .font(.caption)
                
                Label(LocalizedStringKey("reports.credit_card.current_month"), systemImage: "circle.fill")
                    .foregroundColor(.orange)
                    .font(.caption)
            }
            .padding(.top)
        }
    }
    
    private var maxValue: Double {
        let allValues = veriler.flatMap { [$0.oncekiAy, $0.buAy] }
        return allValues.max() ?? 1
    }
    
    private func angleForIndex(_ index: Int, total: Int) -> Double {
        (Double(index) / Double(total)) * 360 - 90
    }
}

// Radar grid şekli
struct RadarGrid: Shape {
    let center: CGPoint
    let radius: CGFloat
    let sides: Int
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        for i in 0..<sides {
            let angle = (Double(i) / Double(sides)) * 360 - 90
            let x = center.x + radius * cos(angle * .pi / 180)
            let y = center.y + radius * sin(angle * .pi / 180)
            
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        path.closeSubpath()
        
        // Merkeze çizgiler
        for i in 0..<sides {
            let angle = (Double(i) / Double(sides)) * 360 - 90
            let x = center.x + radius * cos(angle * .pi / 180)
            let y = center.y + radius * sin(angle * .pi / 180)
            
            path.move(to: center)
            path.addLine(to: CGPoint(x: x, y: y))
        }
        
        return path
    }
}

// Radar şekli
struct RadarShape: Shape {
    let values: [Double]
    let center: CGPoint
    let radius: CGFloat
    let maxValue: Double
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        for i in 0..<values.count {
            let value = min(values[i] / maxValue, 1.0)
            let angle = (Double(i) / Double(values.count)) * 360 - 90
            let x = center.x + radius * value * cos(angle * .pi / 180)
            let y = center.y + radius * value * sin(angle * .pi / 180)
            
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        path.closeSubpath()
        
        return path
    }
}