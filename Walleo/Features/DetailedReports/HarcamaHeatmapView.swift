//
//  HarcamaHeatmapView.swift
//  Walleo
//
//  Created by Mustafa Turan on 14.07.2025.
//


import SwiftUI

struct HarcamaHeatmapView: View {
    let heatmapData: [[KrediKartiRaporViewModel.HeatmapCell]]
    @EnvironmentObject var appSettings: AppSettings
    
    @State private var selectedCell: KrediKartiRaporViewModel.HeatmapCell?
    @State private var animateCells = false
    
    let saatler = ["00", "03", "06", "09", "12", "15", "18", "21"]
    let gunler = ["Pzt", "Sal", "Çar", "Per", "Cum", "Cmt", "Paz"]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("credit_card_report.heatmap.title")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            VStack(spacing: 8) {
                // Saat başlıkları
                HStack(spacing: 4) {
                    Text("")
                        .frame(width: 40)
                    
                    ForEach(saatler, id: \.self) { saat in
                        Text(saat)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                
                // Heatmap grid
                VStack(spacing: 4) {
                    ForEach(Array(heatmapData.enumerated()), id: \.offset) { dayIndex, row in
                        HStack(spacing: 4) {
                            Text(gunler[safe: dayIndex] ?? "")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 40, alignment: .trailing)
                            
                            ForEach(Array(row.enumerated()), id: \.offset) { hourIndex, cell in
                                HeatmapCellView(
                                    cell: cell,
                                    isSelected: selectedCell?.id == cell.id,
                                    animateCell: animateCells,
                                    animationDelay: Double(dayIndex * 8 + hourIndex) * 0.02
                                ) {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        selectedCell = selectedCell?.id == cell.id ? nil : cell
                                    }
                                }
                            }
                        }
                    }
                }
                
                // Renk skalası
                HStack(spacing: 20) {
                    Text("Düşük")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: 2) {
                        ForEach(0..<5) { index in
                            Rectangle()
                                .fill(heatmapColor(intensity: Double(index) / 4))
                                .frame(width: 30, height: 10)
                                .cornerRadius(2)
                        }
                    }
                    
                    Text("Yüksek")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 8)
            }
            
            // Seçili hücre detayı
            if let selected = selectedCell {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                    
                    HStack {
                        Image(systemName: "clock.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Text("\(gunler[selected.gun]) \(String(format: "%02d:00-%02d:00", selected.saat, selected.saat + 3))")
                            .font(.caption.bold())
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text(formatCurrency(
                                amount: selected.toplamTutar,
                                currencyCode: appSettings.currencyCode,
                                localeIdentifier: appSettings.languageCode
                            ))
                            .font(.callout.bold())
                            
                            Text("\(selected.islemSayisi) işlem")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.top, 8)
                .transition(.asymmetric(
                    insertion: .push(from: .bottom).combined(with: .opacity),
                    removal: .push(from: .top).combined(with: .opacity)
                ))
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                animateCells = true
            }
        }
    }
    
    private func heatmapColor(intensity: Double) -> Color {
        let colors: [Color] = [
            .blue.opacity(0.1),
            .blue.opacity(0.3),
            .purple.opacity(0.5),
            .orange.opacity(0.7),
            .red.opacity(0.9)
        ]
        
        let index = Int(intensity * Double(colors.count - 1))
        return colors[safe: index] ?? colors.last!
    }
}

struct HeatmapCellView: View {
    let cell: KrediKartiRaporViewModel.HeatmapCell
    let isSelected: Bool
    let animateCell: Bool
    let animationDelay: Double
    let onTap: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Rectangle()
            .fill(cellColor)
            .frame(maxWidth: .infinity, height: 30)
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
            .scaleEffect(animateCell ? (isHovered ? 1.1 : 1.0) : 0.8)
            .opacity(animateCell ? 1 : 0)
            .animation(.spring(response: 0.4, dampingFraction: 0.8).delay(animationDelay), value: animateCell)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isHovered)
            .onTapGesture(perform: onTap)
            .onHover { hovering in
                isHovered = hovering
            }
    }
    
    private var cellColor: Color {
        let colors: [Color] = [
            .blue.opacity(0.1),
            .blue.opacity(0.3),
            .purple.opacity(0.5),
            .orange.opacity(0.7),
            .red.opacity(0.9)
        ]
        
        let index = Int(cell.yogunluk * Double(colors.count - 1))
        return colors[safe: index] ?? colors.last!
    }
}

// Safe array subscript extension
extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}