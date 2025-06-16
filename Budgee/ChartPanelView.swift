import SwiftUI
import Charts

struct ChartPanelView: View {
    let pieChartVerisi: [KategoriHarcamasi]
    let kategoriDetaylari: [String: (renk: Color, ikon: String)]
    let toplamTutar: Double

    var body: some View {
        if !pieChartVerisi.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                Text("dashboard.category_distribution") // DEĞİŞTİ
                    .font(.headline)
                    .fontWeight(.bold)
                    .padding([.top, .leading, .trailing])
                    .padding(.bottom, 8)
                
                HStack(alignment: .center, spacing: 15) {
                    Chart(pieChartVerisi) { veri in
                        SectorMark(
                            angle: .value("Tutar", veri.tutar),
                            innerRadius: .ratio(0.6),
                            angularInset: 2.0
                        )
                        .foregroundStyle(veri.renk)
                        .cornerRadius(8)
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 2, y: 2)
                    }
                    .frame(width: 140, height: 140)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(pieChartVerisi) { veri in
                            HStack(spacing: 8) {
                                Image(systemName: kategoriDetaylari[veri.kategori]?.ikon ?? "tag.fill")
                                    .font(.callout)
                                    .foregroundColor(veri.renk)
                                    .frame(width: 20)
                                
                                Text(veri.kategori)
                                    .font(.callout)
                                    .lineLimit(2)
                                
                                Spacer()
                                
                                Text(String(format: "%.1f%%", (toplamTutar > 0 ? (veri.tutar / toplamTutar) * 100 : 0)))
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding()
                }
                .padding([.horizontal, .bottom])
            }
            .background(Color(.systemGray6).opacity(0.4))
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }
}
