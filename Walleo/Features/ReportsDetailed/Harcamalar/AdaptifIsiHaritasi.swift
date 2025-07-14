//
//  AdaptifIsiHaritasi.swift
//  Walleo
//
//  Created by Mustafa Turan on 15.07.2025.
//


// >> YENİ DOSYA: Features/ReportsDetailed/Views/AdaptifIsiHaritasi.swift

import SwiftUI

struct AdaptifIsiHaritasi: View {
    let veriler: [ZamanDilimiVerisi]
    let gunSayisi: Int
    @EnvironmentObject var appSettings: AppSettings
    
    @State private var secilenDilim: ZamanDilimiVerisi?
    
    private var gridColumns: [GridItem] {
        let columnCount = getColumnCount()
        return Array(repeating: GridItem(.flexible(), spacing: 4), count: columnCount)
    }
    
    private func getColumnCount() -> Int {
        switch gunSayisi {
        case 1: return 6 // 24 saat için 6x4 grid
        case 2...7: return 7 // Haftalık görünüm
        case 8...35: return 7 // Aylık takvim
        case 36...90: return 4 // Haftalık özet
        default: return 3 // Aylık özet
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Başlık
            HStack {
                Text(getBaslik())
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Spacer()
                
                // Renk skalası göstergesi
                HStack(spacing: 2) {
                    Text("Az")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    ForEach(0..<5) { index in
                        Rectangle()
                            .fill(getColorForIntensity(Double(index) / 4.0))
                            .frame(width: 16, height: 16)
                            .cornerRadius(3)
                    }
                    Text("Çok")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            
            // Isı haritası grid'i
            LazyVGrid(columns: gridColumns, spacing: 4) {
                ForEach(veriler) { dilim in
                    IsiHaritasiHucresi(
                        dilim: dilim,
                        isSelected: secilenDilim?.id == dilim.id
                    )
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3)) {
                            secilenDilim = dilim
                        }
                    }
                }
            }
            
            // Seçili dilim detayı
            if let dilim = secilenDilim {
                DilimDetayView(dilim: dilim)
                    .transition(.asymmetric(
                        insertion: .scale.combined(with: .opacity),
                        removal: .scale.combined(with: .opacity)
                    ))
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
    
    private func getBaslik() -> LocalizedStringKey {
        switch gunSayisi {
        case 1: return "Saatlik Harcama Dağılımı"
        case 2...7: return "Günlük Harcama Dağılımı"
        case 8...35: return "Aylık Harcama Dağılımı"
        case 36...90: return "Haftalık Harcama Dağılımı"
        default: return "Aylık Harcama Özeti"
        }
    }
    
    private func getColorForIntensity(_ intensity: Double) -> Color {
        switch intensity {
        case 0..<0.2: return Color.blue.opacity(0.2)
        case 0.2..<0.4: return Color.green.opacity(0.4)
        case 0.4..<0.6: return Color.yellow.opacity(0.6)
        case 0.6..<0.8: return Color.orange.opacity(0.8)
        default: return Color.red
        }
    }
}

// Isı haritası hücresi
struct IsiHaritasiHucresi: View {
    let dilim: ZamanDilimiVerisi
    let isSelected: Bool
    @EnvironmentObject var appSettings: AppSettings
    
    var body: some View {
        VStack(spacing: 2) {
            Text(getLabel())
                .font(.caption2)
                .foregroundStyle(.secondary)
            
            RoundedRectangle(cornerRadius: 4)
                .fill(getColor())
                .frame(height: 30)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                )
                .scaleEffect(isSelected ? 1.1 : 1.0)
                .shadow(
                    color: isSelected ? Color.accentColor.opacity(0.3) : Color.clear,
                    radius: 4
                )
        }
    }
    
    private func getLabel() -> String {
        switch dilim.periyot {
        case .saat(let date):
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: date)
        case .gun(let date):
            let formatter = DateFormatter()
            formatter.dateFormat = "d"
            return formatter.string(from: date)
        case .hafta(let start, _):
            let formatter = DateFormatter()
            formatter.dateFormat = "d MMM"
            return formatter.string(from: start)
        case .ay(let month, _):
            let formatter = DateFormatter()
            return formatter.monthSymbols[month - 1]
        }
    }
    
    private func getColor() -> Color {
        let intensity = dilim.normalizeEdilmisYogunluk
        switch intensity {
        case 0: return Color(.systemGray6)
        case 0..<0.2: return Color.blue.opacity(0.3)
        case 0.2..<0.4: return Color.green.opacity(0.5)
        case 0.4..<0.6: return Color.yellow.opacity(0.7)
        case 0.6..<0.8: return Color.orange.opacity(0.8)
        default: return Color.red.opacity(0.9)
        }
    }
}

// Seçili dilim detayı
struct DilimDetayView: View {
    let dilim: ZamanDilimiVerisi
    @EnvironmentObject var appSettings: AppSettings
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(getPeriodText())
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Text(formatCurrency(
                    amount: dilim.toplamTutar,
                    currencyCode: appSettings.currencyCode,
                    localeIdentifier: appSettings.languageCode
                ))
                .font(.headline)
                .fontWeight(.bold)
            }
            
            Text("\(dilim.islemSayisi) işlem")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.tertiarySystemGroupedBackground))
        .cornerRadius(8)
    }
    
    private func getPeriodText() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: appSettings.languageCode)
        
        switch dilim.periyot {
        case .saat(let date):
            formatter.dateFormat = "d MMMM HH:mm"
            return formatter.string(from: date)
        case .gun(let date):
            formatter.dateFormat = "d MMMM yyyy"
            return formatter.string(from: date)
        case .hafta(let start, let end):
            formatter.dateFormat = "d MMM"
            return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
        case .ay(let month, let year):
            formatter.dateFormat = "MMMM yyyy"
            let date = Calendar.current.date(from: DateComponents(year: year, month: month))!
            return formatter.string(from: date)
        }
    }
}