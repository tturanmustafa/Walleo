// Walleo/Features/ReportsDetailed/InteractiveLineChartView.swift

import SwiftUI
import Charts

struct InteractiveLineChartView: View {
    let data: [GunlukHarcama]
    let renk: Color
    @EnvironmentObject var appSettings: AppSettings

    @State private var secilenTarih: Date?
    
    private var toplamTutar: Double {
        data.reduce(0) { $0 + $1.tutar }
    }
    private var gunlukOrtalama: Double {
        guard !data.isEmpty else { return 0 }
        return toplamTutar / Double(data.count)
    }
    
    private var secilenVeri: GunlukHarcama? {
        guard let secilenTarih else { return nil }
        return data.min(by: { abs($0.gun.timeIntervalSince(secilenTarih)) < abs($1.gun.timeIntervalSince(secilenTarih)) })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("reports.detailed.daily_spending_trend")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            HStack(spacing: 16) {
                VStack(alignment: .leading) {
                    Text("common.total")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(formatCurrency(amount: toplamTutar, currencyCode: appSettings.currencyCode, localeIdentifier: appSettings.languageCode))
                        .font(.callout.bold())
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                VStack(alignment: .leading) {
                    Text("reports.statistics.daily_avg_expense")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(formatCurrency(amount: gunlukOrtalama, currencyCode: appSettings.currencyCode, localeIdentifier: appSettings.languageCode))
                        .font(.callout.bold())
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            Chart {
                ForEach(data) { gunlukHarcama in
                    AreaMark(
                        x: .value("Gün", gunlukHarcama.gun, unit: .day),
                        y: .value("Tutar", gunlukHarcama.tutar)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(LinearGradient(
                        gradient: Gradient(colors: [renk.opacity(0.4), .clear]),
                        startPoint: .top,
                        endPoint: .bottom
                    ))
                }
                
                ForEach(data) { gunlukHarcama in
                    LineMark(
                        x: .value("Gün", gunlukHarcama.gun, unit: .day),
                        y: .value("Tutar", gunlukHarcama.tutar)
                    )
                    .foregroundStyle(renk)
                    .interpolationMethod(.catmullRom)
                    .symbol(.circle)
                    .symbolSize(CGSize(width: 8, height: 8))
                }
                
                if let secilenVeri {
                    // --- 🔥 HATA DÜZELTMESİ VE İYİLEŞTİRME BURADA 🔥 ---
                    // Hatalı olan .overlay yerine, üst üste iki PointMark çiziyoruz.
                    
                    // 1. HALKA (Büyük ve Renkli Olan)
                    PointMark(
                        x: .value("Seçilen Gün", secilenVeri.gun),
                        y: .value("Seçilen Tutar", secilenVeri.tutar)
                    )
                    .symbolSize(CGSize(width: 15, height: 15))
                    .foregroundStyle(renk.opacity(0.5)) // Halkayı hafifçe saydam yapıyoruz
                    
                    // 2. MERKEZ NOKTA (Küçük ve Beyaz Olan)
                    PointMark(
                        x: .value("Seçilen Gün", secilenVeri.gun),
                        y: .value("Seçilen Tutar", secilenVeri.tutar)
                    )
                    .symbolSize(CGSize(width: 8, height: 8))
                    .foregroundStyle(Color.white)
                    
                    // 3. MERKEZ NOKTANIN GÖLGESİ (Derinlik için)
                    PointMark(
                        x: .value("Seçilen Gün", secilenVeri.gun),
                        y: .value("Seçilen Tutar", secilenVeri.tutar)
                    )
                    .symbolSize(CGSize(width: 8, height: 8))
                    .foregroundStyle(renk)
                    .shadow(color: .black.opacity(0.1), radius: 2, y: 1)

                    // Dikey kesikli çizgi
                    RuleMark(x: .value("Seçilen Gün", secilenVeri.gun))
                        .foregroundStyle(Color.gray.opacity(0.35))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 6]))
                        .annotation(position: .top, alignment: .center, spacing: 10) {
                            VStack(spacing: 4) {
                                Text(formatChartDate(secilenVeri.gun))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(formatCurrency(amount: secilenVeri.tutar, currencyCode: appSettings.currencyCode, localeIdentifier: appSettings.languageCode))
                                    .font(.headline.bold())
                                    .foregroundStyle(.primary)
                            }
                            .padding(10)
                            .background(Color(.systemBackground))
                            .cornerRadius(8)
                            .shadow(color: .black.opacity(0.1), radius: 5, y: 2)
                        }
                    // --- 🔥 DÜZELTME SONU 🔥 ---
                }
            }
            .frame(height: 200)
            .chartXSelection(value: $secilenTarih)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
    private func formatChartDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: appSettings.languageCode)
        formatter.dateFormat = "d MMM"
        return formatter.string(from: date)
    }
}
