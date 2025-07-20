//
//  RadyalSaatGrafigi.swift
//  Walleo
//
//  Created by Mustafa Turan on 20.07.2025.
//


// Features/ReportsDetailed/Components/ModernRadyalSaatGrafigi.swift

import SwiftUI
import Charts

struct RadyalSaatGrafigi: View {
    let saatlikDagilim: [SaatlikDagilimVerisi]
    @EnvironmentObject var appSettings: AppSettings
    @State private var secilenSaat: Int?
    @State private var animasyonTamamlandi = false
    
    private var maksimumDeger: Double {
        saatlikDagilim.map { $0.toplamTutar }.max() ?? 1
    }
    
    private var toplamHarcama: Double {
        saatlikDagilim.reduce(0) { $0 + $1.toplamTutar }
    }
    
    private var enYogunSaatler: [Int] {
        saatlikDagilim
            .filter { $0.toplamTutar > 0 }
            .sorted { $0.toplamTutar > $1.toplamTutar }
            .prefix(3)
            .map { $0.saat }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Üst bilgi ve seçili saat detayı
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("reports.category.hourly_activity")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    
                    if let saat = secilenSaat,
                       let veri = saatlikDagilim.first(where: { $0.saat == saat }) {
                        HStack(spacing: 8) {
                            Text("\(saat):00-\((saat + 1) % 24):00")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text("•")
                                .foregroundStyle(.secondary)
                            
                            Text(formatCurrency(
                                amount: veri.toplamTutar,
                                currencyCode: appSettings.currencyCode,
                                localeIdentifier: appSettings.languageCode
                            ))
                            .font(.subheadline.bold())
                            .foregroundColor(.accentColor)
                        }
                        .transition(.asymmetric(
                            insertion: .scale.combined(with: .opacity),
                            removal: .scale.combined(with: .opacity)
                        ))
                    }
                }
                
                Spacer()
                
                // Toplam harcama
                VStack(alignment: .trailing, spacing: 2) {
                    Text("common.total")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(formatCurrency(
                        amount: toplamHarcama,
                        currencyCode: appSettings.currencyCode,
                        localeIdentifier: appSettings.languageCode
                    ))
                    .font(.headline.bold())
                }
            }
            
            // Ana radyal grafik
            ZStack {
                // Arka plan katmanları
                ForEach([0.2, 0.4, 0.6, 0.8, 1.0], id: \.self) { radius in
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [Color.gray.opacity(0.1), Color.gray.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                        .frame(width: 240 * radius, height: 240 * radius)
                }
                
                // Saat işaretleri ve etiketler
                ForEach(0..<24, id: \.self) { hour in
                    GeometryReader { geo in
                        let angle = Double(hour) * 15 - 90
                        let isMainHour = hour % 6 == 0
                        let radius: CGFloat = 120
                        
                        // Saat etiketi
                        if isMainHour {
                            Text("\(hour)")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)
                                .position(
                                    x: geo.size.width / 2 + (radius + 20) * cos(angle * .pi / 180),
                                    y: geo.size.height / 2 + (radius + 20) * sin(angle * .pi / 180)
                                )
                        }
                        
                        // Saat işareti
                        Circle()
                            .fill(Color.gray.opacity(isMainHour ? 0.5 : 0.3))
                            .frame(width: isMainHour ? 4 : 2, height: isMainHour ? 4 : 2)
                            .position(
                                x: geo.size.width / 2 + radius * cos(angle * .pi / 180),
                                y: geo.size.height / 2 + radius * sin(angle * .pi / 180)
                            )
                    }
                    .frame(width: 280, height: 280)
                }
                
                // Veri barları
                ForEach(saatlikDagilim) { veri in
                    RadyalBar(
                        veri: veri,
                        maksimumDeger: maksimumDeger,
                        isHighlighted: enYogunSaatler.contains(veri.saat),
                        isSelected: secilenSaat == veri.saat,
                        animasyonTamamlandi: animasyonTamamlandi
                    )
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3)) {
                            secilenSaat = secilenSaat == veri.saat ? nil : veri.saat
                        }
                    }
                }
                
                // Merkez bilgi
                VStack(spacing: 8) {
                    Image(systemName: "clock.fill")
                        .font(.title)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.accentColor, .accentColor.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    Text("24h")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    
                    if let saat = secilenSaat,
                       let veri = saatlikDagilim.first(where: { $0.saat == saat }) {
                        VStack(spacing: 2) {
                            Text("\(veri.islemSayisi)")
                                .font(.headline.bold())
                            Text("reports.category.transactions")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .frame(width: 100)
                .opacity(secilenSaat == nil ? 1 : 0.8)
            }
            .frame(width: 280, height: 280)
            .onAppear {
                withAnimation(.easeOut(duration: 1.0).delay(0.2)) {
                    animasyonTamamlandi = true
                }
            }
            
            // En yoğun saatler
            if !enYogunSaatler.isEmpty {
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "flame.fill")
                            .font(.callout)
                            .foregroundColor(.orange)
                        
                        Text("reports.category.busiest_hours")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                    }
                    
                    HStack(spacing: 12) {
                        ForEach(enYogunSaatler.prefix(3), id: \.self) { saat in
                            if let veri = saatlikDagilim.first(where: { $0.saat == saat }) {
                                VStack(spacing: 4) {
                                    Text("\(saat):00")
                                        .font(.caption.bold())
                                    
                                    Text(formatCurrency(
                                        amount: veri.toplamTutar,
                                        currencyCode: appSettings.currencyCode,
                                        localeIdentifier: appSettings.languageCode
                                    ))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Color.orange.opacity(0.1))
                                .cornerRadius(8)
                            }
                        }
                    }
                }
            }
        }
        .padding()
    }
}

// Radyal bar bileşeni
struct RadyalBar: View {
    let veri: SaatlikDagilimVerisi
    let maksimumDeger: Double
    let isHighlighted: Bool
    let isSelected: Bool
    let animasyonTamamlandi: Bool
    
    private var normalizedHeight: Double {
        guard maksimumDeger > 0 else { return 0 }
        return (veri.toplamTutar / maksimumDeger) * 80 // Maksimum 80 piksel
    }
    
    private var angle: Double {
        Double(veri.saat) * 15 - 90
    }
    
    private var barColor: LinearGradient {
        let baseColor: Color
        if isSelected {
            baseColor = .accentColor
        } else if isHighlighted {
            baseColor = .orange
        } else if veri.toplamTutar == 0 {
            baseColor = .gray.opacity(0.3)
        } else {
            baseColor = .blue
        }
        
        return LinearGradient(
            colors: [baseColor, baseColor.opacity(0.7)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(barColor)
            .frame(width: isSelected ? 12 : 10, height: animasyonTamamlandi ? normalizedHeight : 0)
            .shadow(
                color: isSelected ? Color.accentColor.opacity(0.3) : .clear,
                radius: 4,
                y: 2
            )
            .offset(y: -normalizedHeight / 2 - 60)
            .rotationEffect(.degrees(angle))
            .scaleEffect(isSelected ? 1.1 : 1.0)
            .animation(.spring(response: 0.3), value: isSelected)
    }
}

// SaatlikDagilimVerisi modeli (eğer başka yerde tanımlı değilse)
struct SaatlikDagilimVerisi: Identifiable {
    let id = UUID()
    let saat: Int
    let toplamTutar: Double
    let islemSayisi: Int
    let yuzde: Double
}