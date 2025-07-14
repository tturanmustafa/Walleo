//
//  KategoriAnaliziView.swift
//  Walleo
//
//  Created by Mustafa Turan on 14.07.2025.
//


import SwiftUI

struct KategoriAnaliziView: View {
    let kategoriHarcamalari: [KrediKartiRaporViewModel.KategoriHarcama]
    @EnvironmentObject var appSettings: AppSettings
    
    @State private var expandedCategories: Set<UUID> = []
    @State private var animateCards = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("credit_card_report.category_analysis")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            VStack(spacing: 12) {
                ForEach(Array(kategoriHarcamalari.enumerated()), id: \.element.id) { index, kategori in
                    KategoriCardView(
                        kategori: kategori,
                        isExpanded: expandedCategories.contains(kategori.id),
                        animateCard: animateCards,
                        animationDelay: Double(index) * 0.1
                    ) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            if expandedCategories.contains(kategori.id) {
                                expandedCategories.remove(kategori.id)
                            } else {
                                expandedCategories.insert(kategori.id)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) {
                animateCards = true
            }
        }
    }
}

struct KategoriCardView: View {
    let kategori: KrediKartiRaporViewModel.KategoriHarcama
    let isExpanded: Bool
    let animateCard: Bool
    let animationDelay: Double
    let onTap: () -> Void
    
    @EnvironmentObject var appSettings: AppSettings
    @State private var showDetails = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Ana kart içeriği
            HStack(spacing: 16) {
                // Kategori ikonu
                ZStack {
                    Circle()
                        .fill(kategori.renk.opacity(0.2))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: kategori.ikonAdi)
                        .font(.title2)
                        .foregroundColor(kategori.renk)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                
                // Kategori bilgileri
                VStack(alignment: .leading, spacing: 4) {
                    Text(LocalizedStringKey(kategori.kategoriAdi))
                        .font(.subheadline.bold())
                    
                    Text("\(kategori.islemSayisi) işlem")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Tutar ve yüzde
                VStack(alignment: .trailing, spacing: 4) {
                    Text(formatCurrency(
                        amount: kategori.toplamTutar,
                        currencyCode: appSettings.currencyCode,
                        localeIdentifier: appSettings.languageCode
                    ))
                    .font(.callout.bold())
                    
                    Text(String(format: "%.1f%%", kategori.yuzde))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(kategori.renk.opacity(0.2)))
                }
                
                // Expand ikonu
                Image(systemName: "chevron.down")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
                    .rotationEffect(.degrees(isExpanded ? -180 : 0))
            }
            .padding()
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)
            
            // Genişletilmiş içerik
            if isExpanded {
                VStack(spacing: 12) {
                    Divider()
                    
                    // Mini istatistikler
                    HStack(spacing: 20) {
                        StatisticView(
                            title: "Ortalama",
                            value: formatCurrency(
                                amount: kategori.ortalamaIslemTutari,
                                currencyCode: appSettings.currencyCode,
                                localeIdentifier: appSettings.languageCode
                            ),
                            icon: "chart.line.uptrend.xyaxis"
                        )
                        
                        StatisticView(
                            title: "En Yüksek",
                            value: formatCurrency(
                                amount: kategori.enYuksekIslem,
                                currencyCode: appSettings.currencyCode,
                                localeIdentifier: appSettings.languageCode
                            ),
                            icon: "arrow.up.circle.fill"
                        )
                        
                        StatisticView(
                            title: "En Düşük",
                            value: formatCurrency(
                                amount: kategori.enDusukIslem,
                                currencyCode: appSettings.currencyCode,
                                localeIdentifier: appSettings.languageCode
                            ),
                            icon: "arrow.down.circle.fill"
                        )
                    }
                    .padding(.horizontal)
                    
                    // Mini grafik
                    if !kategori.gunlukDagilim.isEmpty {
                        MiniChartView(data: kategori.gunlukDagilim, color: kategori.renk)
                            .frame(height: 60)
                            .padding(.horizontal)
                    }
                }
                .padding(.bottom)
                .transition(.asymmetric(
                    insertion: .push(from: .top).combined(with: .opacity),
                    removal: .push(from: .bottom).combined(with: .opacity)
                ))
            }
        }
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .scaleEffect(animateCard ? 1 : 0.8)
        .opacity(animateCard ? 1 : 0)
        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(animationDelay), value: animateCard)
    }
}

struct StatisticView: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Text(value)
                .font(.caption.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct MiniChartView: View {
    let data: [Double]
    let color: Color
    
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                guard !data.isEmpty else { return }
                
                let width = geometry.size.width
                let height = geometry.size.height
                let maxValue = data.max() ?? 1
                let stepX = width / CGFloat(data.count - 1)
                
                for (index, value) in data.enumerated() {
                    let x = CGFloat(index) * stepX
                    let y = height - (CGFloat(value / maxValue) * height)
                    
                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            
            // Gradient area
            Path { path in
                guard !data.isEmpty else { return }
                
                let width = geometry.size.width
                let height = geometry.size.height
                let maxValue = data.max() ?? 1
                let stepX = width / CGFloat(data.count - 1)
                
                path.move(to: CGPoint(x: 0, y: height))
                
                for (index, value) in data.enumerated() {
                    let x = CGFloat(index) * stepX
                    let y = height - (CGFloat(value / maxValue) * height)
                    path.addLine(to: CGPoint(x: x, y: y))
                }
                
                path.addLine(to: CGPoint(x: width, y: height))
                path.closeSubpath()
            }
            .fill(
                LinearGradient(
                    colors: [color.opacity(0.3), color.opacity(0.05)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }
}