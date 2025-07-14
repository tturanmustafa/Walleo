//
//  KrediKarsilastirmaView.swift
//  Walleo
//
//  Created by Mustafa Turan on 14.07.2025.
//


import SwiftUI

struct KrediKarsilastirmaView: View {
    let karsilastirmalar: [KrediRaporViewModel.KrediKarsilastirma]
    @EnvironmentObject var appSettings: AppSettings
    
    @State private var selectedKrediID: UUID?
    @State private var animateChart = false
    
    private let metrics = ["Faiz Oranı", "Kalan Taksit", "Aylık Yük", "Toplam Borç"]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("loan_report.comparison.title")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            // Radar Chart
            GeometryReader { geometry in
                ZStack {
                    // Arka plan grid
                    RadarChartGrid(
                        categories: metrics,
                        gridLevels: 5,
                        size: geometry.size
                    )
                    
                    // Kredi verileri
                    ForEach(karsilastirmalar) { kredi in
                        RadarChartPath(
                            data: normalizeData(for: kredi),
                            categories: metrics,
                            color: kredi.renk,
                            size: geometry.size,
                            animate: animateChart,
                            isHighlighted: selectedKrediID == kredi.id
                        )
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.width)
            }
            .aspectRatio(1, contentMode: .fit)
            .padding()
            
            // Kredi listesi (legend)
            VStack(spacing: 12) {
                ForEach(karsilastirmalar) { kredi in
                    KrediLegendRow(
                        kredi: kredi,
                        isSelected: selectedKrediID == kredi.id
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedKrediID = selectedKrediID == kredi.id ? nil : kredi.id
                        }
                    }
                    .environmentObject(appSettings)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).delay(0.2)) {
                animateChart = true
            }
        }
    }
    
    private func normalizeData(for kredi: KrediRaporViewModel.KrediKarsilastirma) -> [Double] {
        // Tüm krediler arasındaki maksimum değerleri bul
        let maxFaiz = karsilastirmalar.map { $0.faizOrani }.max() ?? 1
        let maxTaksit = Double(karsilastirmalar.map { $0.kalanTaksitSayisi }.max() ?? 1)
        let maxAylik = karsilastirmalar.map { $0.aylikYuk }.max() ?? 1
        let maxBorc = karsilastirmalar.map { $0.toplamKalanBorc }.max() ?? 1
        
        // Normalize et (0-1 arası)
        return [
            kredi.faizOrani / maxFaiz,
            Double(kredi.kalanTaksitSayisi) / maxTaksit,
            kredi.aylikYuk / maxAylik,
            kredi.toplamKalanBorc / maxBorc
        ]
    }
}

struct RadarChartGrid: View {
    let categories: [String]
    let gridLevels: Int
    let size: CGSize
    
    var body: some View {
        ZStack {
            // Grid çizgileri
            ForEach(1...gridLevels, id: \.self) { level in
                Path { path in
                    let radius = (size.width / 2) * (CGFloat(level) / CGFloat(gridLevels))
                    let center = CGPoint(x: size.width / 2, y: size.height / 2)
                    
                    for i in 0..<categories.count {
                        let angle = (2 * .pi / CGFloat(categories.count)) * CGFloat(i) - .pi / 2
                        let x = center.x + radius * cos(angle)
                        let y = center.y + radius * sin(angle)
                        
                        if i == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                    path.closeSubpath()
                }
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            }
            
            // Eksen çizgileri ve etiketler
            ForEach(0..<categories.count, id: \.self) { i in
                let angle = (2 * .pi / CGFloat(categories.count)) * CGFloat(i) - .pi / 2
                let lineEnd = CGPoint(
                    x: size.width / 2 + (size.width / 2) * cos(angle),
                    y: size.height / 2 + (size.height / 2) * sin(angle)
                )
                let labelPosition = CGPoint(
                    x: size.width / 2 + (size.width / 2 + 20) * cos(angle),
                    y: size.height / 2 + (size.height / 2 + 20) * sin(angle)
                )
                
                Path { path in
                    path.move(to: CGPoint(x: size.width / 2, y: size.height / 2))
                    path.addLine(to: lineEnd)
                }
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                
                Text(categories[i])
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .position(labelPosition)
            }
        }
    }
}

struct RadarChartPath: View {
    let data: [Double]
    let categories: [String]
    let color: Color
    let size: CGSize
    let animate: Bool
    let isHighlighted: Bool
    
    @State private var animationProgress: CGFloat = 0
    
    var body: some View {
        ZStack {
            // Dolu alan
            Path { path in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                
                for i in 0..<data.count {
                    let angle = (2 * .pi / CGFloat(data.count)) * CGFloat(i) - .pi / 2
                    let radius = (size.width / 2) * data[i] * (animate ? animationProgress : 0)
                    let x = center.x + radius * cos(angle)
                    let y = center.y + radius * sin(angle)
                    
                    if i == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
                path.closeSubpath()
            }
            .fill(color.opacity(isHighlighted ? 0.3 : 0.1))
            
            // Çizgi
            Path { path in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                
                for i in 0..<data.count {
                    let angle = (2 * .pi / CGFloat(data.count)) * CGFloat(i) - .pi / 2
                    let radius = (size.width / 2) * data[i] * (animate ? animationProgress : 0)
                    let x = center.x + radius * cos(angle)
                    let y = center.y + radius * sin(angle)
                    
                    if i == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
                path.closeSubpath()
            }
            .stroke(color, lineWidth: isHighlighted ? 3 : 2)
            
            // Nokta işaretleri
            ForEach(0..<data.count, id: \.self) { i in
                let angle = (2 * .pi / CGFloat(data.count)) * CGFloat(i) - .pi / 2
                let radius = (size.width / 2) * data[i] * (animate ? animationProgress : 0)
                let x = size.width / 2 + radius * cos(angle)
                let y = size.height / 2 + radius * sin(angle)
                
                Circle()
                    .fill(color)
                    .frame(width: isHighlighted ? 8 : 6, height: isHighlighted ? 8 : 6)
                    .position(x: x, y: y)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8)) {
                animationProgress = 1
            }
        }
    }
}

struct KrediLegendRow: View {
    let kredi: KrediRaporViewModel.KrediKarsilastirma
    let isSelected: Bool
    let onTap: () -> Void
    
    @EnvironmentObject var appSettings: AppSettings
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(kredi.renk)
                .frame(width: 12, height: 12)
            
            Text(kredi.krediAdi)
                .font(.subheadline)
                .fontWeight(isSelected ? .bold : .regular)
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatCurrency(
                    amount: kredi.aylikYuk,
                    currencyCode: appSettings.currencyCode,
                    localeIdentifier: appSettings.languageCode
                ))
                .font(.caption.bold())
                
                Text("Aylık")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? kredi.renk.opacity(0.1) : Color.clear)
        )
        .onTapGesture(perform: onTap)
    }
}