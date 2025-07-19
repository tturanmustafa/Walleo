// >> TAM GÜNCELLENECEK DOSYA: PeriyodikKarsilastirmaView.swift

import SwiftUI
import Charts

struct PeriyodikKarsilastirmaView: View {
    let veriler: [HarcamaKarsilastirmaVerisi]
    @EnvironmentObject var appSettings: AppSettings
    
    @State private var secilenVeri: HarcamaKarsilastirmaVerisi?
    @State private var secilenX: String?
    
    private var ortalamaDeger: Double {
        guard !veriler.isEmpty else { return 0 }
        return veriler.reduce(0) { $0 + $1.deger } / Double(veriler.count)
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Başlık ve seçili veri detayı
            HStack {
                Text("reports.heatmap.comparison")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                // Seçili veri detayını sağ üstte göster
                if let veri = secilenVeri {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(veri.localizationKey != nil
                            ? NSLocalizedString(veri.localizationKey!, comment: "")
                            : veri.etiket)
                            .font(.caption)
                            .fontWeight(.medium)
                        Text(formatCurrency(
                            amount: veri.deger,
                            currencyCode: appSettings.currencyCode,
                            localeIdentifier: appSettings.languageCode
                        ))
                        .font(.subheadline.bold())
                        .foregroundColor(.accentColor)
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            
            if veriler.isEmpty {
                ContentUnavailableView(
                    LocalizedStringKey("reports.comparison.no_data_title"),
                    systemImage: "chart.bar.fill"
                )
                .frame(height: 120)
            } else {
                Chart(veriler) { veri in
                    BarMark(
                        x: .value("Periyot", veri.localizationKey != nil
                            ? NSLocalizedString(veri.localizationKey!, comment: "")
                            : veri.etiket),
                        y: .value("Tutar", veri.deger)
                    )
                    .foregroundStyle(
                        secilenVeri?.id == veri.id ? Color.accentColor : veri.renk
                    )
                    .cornerRadius(4)
                    
                    // Ortalama çizgisi
                    RuleMark(y: .value(NSLocalizedString("common.average", comment: ""), ortalamaDeger))
                        .foregroundStyle(.gray.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))
                }
                .frame(height: 180)
                .chartXAxis {
                    AxisMarks { value in
                        AxisValueLabel()
                            .font(.caption)
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let doubleValue = value.as(Double.self) {
                                Text(formatCurrency(
                                    amount: doubleValue,
                                    currencyCode: appSettings.currencyCode,
                                    localeIdentifier: appSettings.languageCode
                                ))
                                .font(.caption2)
                            }
                        }
                    }
                }
                // X ekseninde seçim yapmayı sağlayan modifier
                .chartXSelection(value: $secilenX)
                .onChange(of: secilenX) { _, newValue in
                    withAnimation(.spring(response: 0.3)) {
                        if let selectedLabel = newValue {
                            // Seçilen etikete göre veriyi bul
                            secilenVeri = veriler.first { veri in
                                let label = veri.localizationKey != nil
                                    ? NSLocalizedString(veri.localizationKey!, comment: "")
                                    : veri.etiket
                                return label == selectedLabel
                            }
                        } else {
                            secilenVeri = nil
                        }
                    }
                }
                
                // Özet bilgi - alt kısım
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(LocalizedStringKey("common.highest"))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        if let maxVeri = veriler.max(by: { $0.deger < $1.deger }) {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(maxVeri.renk)
                                    .frame(width: 8, height: 8)
                                Text(maxVeri.localizationKey != nil
                                    ? NSLocalizedString(maxVeri.localizationKey!, comment: "")
                                    : maxVeri.etiket)
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            Text(formatCurrency(
                                amount: maxVeri.deger,
                                currencyCode: appSettings.currencyCode,
                                localeIdentifier: appSettings.languageCode
                            ))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(LocalizedStringKey("common.average"))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(formatCurrency(
                            amount: ortalamaDeger,
                            currencyCode: appSettings.currencyCode,
                            localeIdentifier: appSettings.languageCode
                        ))
                        .font(.caption)
                        .fontWeight(.medium)
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
}
