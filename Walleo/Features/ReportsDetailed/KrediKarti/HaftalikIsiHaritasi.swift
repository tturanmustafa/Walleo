//
//  HaftalikIsiHaritasi.swift
//  Walleo
//
//  Created by Mustafa Turan on 15.07.2025.
//


// >> YENİ DOSYA: Features/ReportsDetailed/Views/HaftalikIsiHaritasi.swift

import SwiftUI

struct HaftalikIsiHaritasi: View {
    let veriler: [HaftalikHarcama]
    let animasyonTamamlandi: Bool
    @EnvironmentObject var appSettings: AppSettings
    
    @State private var secilenGun: GunlukVeri?
    @State private var hoveredGun: GunlukVeri?
    
    private let gunler = ["Pzt", "Sal", "Çar", "Per", "Cum", "Cmt", "Paz"]
    
    private var maxHarcama: Double {
        veriler.flatMap { $0.gunler }.map { $0.harcama }.max() ?? 1
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Başlık ve renk skalası
            HStack {
                Text(LocalizedStringKey("reports.credit_card.weekly_spending_pattern"))
                    .font(.headline)
                
                Spacer()
                
                // Renk skalası
                HStack(spacing: 4) {
                    Text(LocalizedStringKey("reports.heatmap.low"))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    ForEach(0..<5) { index in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(colorForIntensity(Double(index) / 4.0))
                            .frame(width: 20, height: 20)
                    }
                    
                    Text(LocalizedStringKey("reports.heatmap.high"))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            // Isı haritası grid
            VStack(spacing: 8) {
                // Gün başlıkları
                HStack(spacing: 8) {
                    Text("") // Hafta etiketi için boşluk
                        .frame(width: 50)
                    
                    ForEach(gunler, id: \.self) { gun in
                        Text(LocalizedStringKey("day.short.\(gun.lowercased())"))
                            .font(.caption.bold())
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Haftalık veriler
                ForEach(Array(veriler.enumerated()), id: \.element.id) { index, hafta in
                    HStack(spacing: 8) {
                        // Hafta etiketi
                        Text("H\(index + 1)")
                            .font(.caption.bold())
                            .frame(width: 50)
                            .foregroundColor(.secondary)
                        
                        // Günlük hücreler
                        ForEach(hafta.gunler) { gun in
                            IsiHaritasiHucresi(
                                gun: gun,
                                maxHarcama: maxHarcama,
                                isSelected: secilenGun?.id == gun.id,
                                isHovered: hoveredGun?.id == gun.id,
                                animasyonTamamlandi: animasyonTamamlandi
                            )
                            .onTapGesture {
                                withAnimation(.spring(response: 0.3)) {
                                    secilenGun = secilenGun?.id == gun.id ? nil : gun
                                }
                            }
                            .onHover { isHovered in
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    hoveredGun = isHovered ? gun : nil
                                }
                            }
                        }
                    }
                }
            }
            
            // Seçilen gün detayı
            if let gun = secilenGun {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(gun.gun, format: .dateTime.weekday(.wide).day().month())
                            .font(.subheadline.bold())
                        
                        Text(formatCurrency(
                            amount: gun.harcama,
                            currencyCode: appSettings.currencyCode,
                            localeIdentifier: appSettings.languageCode
                        ))
                        .font(.headline)
                        .foregroundColor(.primary)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        withAnimation {
                            secilenGun = nil
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(.tertiarySystemGroupedBackground))
                .cornerRadius(12)
                .transition(.asymmetric(
                    insertion: .scale.combined(with: .opacity),
                    removal: .scale.combined(with: .opacity)
                ))
            }
        }
    }
    
    private func colorForIntensity(_ intensity: Double) -> Color {
        let baseColor = Color.blue
        switch intensity {
        case 0: return Color(.systemGray6)
        case 0..<0.2: return baseColor.opacity(0.2)
        case 0.2..<0.4: return baseColor.opacity(0.4)
        case 0.4..<0.6: return baseColor.opacity(0.6)
        case 0.6..<0.8: return baseColor.opacity(0.8)
        default: return baseColor
        }
    }
}

struct IsiHaritasiHucresi: View {
    let gun: GunlukVeri
    let maxHarcama: Double
    let isSelected: Bool
    let isHovered: Bool
    let animasyonTamamlandi: Bool
    @EnvironmentObject var appSettings: AppSettings
    
    private var yogunluk: Double {
        guard maxHarcama > 0 else { return 0 }
        return gun.harcama / maxHarcama
    }
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(colorForIntensity(animasyonTamamlandi ? yogunluk : 0))
                .frame(height: 45)
                .scaleEffect(isSelected ? 1.15 : (isHovered ? 1.05 : 1.0))
                .shadow(
                    color: isSelected ? Color.accentColor.opacity(0.3) : Color.clear,
                    radius: isSelected ? 8 : 0
                )
            
            if gun.harcama > 0 && animasyonTamamlandi {
                Text(formatCompactCurrency(gun.harcama))
                    .font(.caption2.bold())
                    .foregroundColor(yogunluk > 0.5 ? .white : .primary)
                    .opacity(isHovered || isSelected ? 1 : 0.8)
            }
            
            if isSelected {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.accentColor, lineWidth: 2)
            }
        }
        .animation(.spring(response: 0.3), value: isSelected)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
    }
    
    private func colorForIntensity(_ intensity: Double) -> Color {
        let gradientColors: [Color] = [
            Color(.systemGray6),
            Color.blue.opacity(0.3),
            Color.blue.opacity(0.5),
            Color.orange.opacity(0.7),
            Color.red.opacity(0.8),
            Color.red
        ]
        
        let index = Int(intensity * Double(gradientColors.count - 1))
        return gradientColors[min(index, gradientColors.count - 1)]
    }
    
    private func formatCompactCurrency(_ amount: Double) -> String {
        if amount >= 1000 {
            return String(format: "%.0fK", amount / 1000)
        } else {
            return String(format: "%.0f", amount)
        }
    }
}