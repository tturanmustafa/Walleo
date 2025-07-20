import SwiftUI
import Charts

struct ChartPanelView: View {
    let pieChartVerisi: [KategoriHarcamasi]
    let kategoriDetaylari: [String: (renk: Color, ikon: String)]
    let toplamTutar: Double
    
    // YENİ: Yüzdeleri bir kere hesapla
    private var kategorilerVeYuzdeler: [(veri: KategoriHarcamasi, yuzde: String)] {
        pieChartVerisi.map { veri in
            let yuzde = toplamTutar > 0 ? (veri.tutar / toplamTutar) * 100 : 0
            return (veri, String(format: "%.1f%%", yuzde))
        }
    }

    var body: some View {
        if !pieChartVerisi.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                Text("dashboard.category_distribution")
                    .font(.headline)
                    .fontWeight(.bold)
                    .padding([.top, .leading, .trailing])
                    .padding(.bottom, 14)
                
                HStack(alignment: .center, spacing: 15) {
                    // YENİ: Chart'ı memoize et
                    chartView
                        .frame(width: 140, height: 140)
                    
                    // YENİ: Liste performansını artır
                    categoryListView
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.trailing)
                }
                .padding([.leading, .bottom])
                .frame(height: 150)
            }
            .background(Color(.systemGray6).opacity(0.4))
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }
    
    // YENİ: Chart'ı ayrı view'a çıkar
    @ViewBuilder
    private var chartView: some View {
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
        // YENİ: Chart animasyonlarını kontrol et
        .animation(.easeInOut(duration: 0.5), value: pieChartVerisi.map { $0.tutar })
    }
    
    // YENİ: Kategori listesini ayrı view'a çıkar
    @ViewBuilder
    private var categoryListView: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(kategorilerVeYuzdeler, id: \.veri.id) { item in
                CategoryRowView(
                    veri: item.veri,
                    yuzde: item.yuzde,
                    ikon: kategoriDetaylari[item.veri.kategori]?.ikon ?? "tag.fill"
                )
            }
        }
    }
}

// YENİ: Kategori satırını ayrı struct'a çıkar
struct CategoryRowView: View {
    let veri: KategoriHarcamasi
    let yuzde: String
    let ikon: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: ikon)
                .font(.callout)
                .foregroundColor(veri.renk)
                .frame(width: 20)
            
            Text(LocalizedStringKey(veri.localizationKey ?? veri.kategori))
                .font(.callout)
                .lineLimit(1)
            
            Spacer()
            
            Text(yuzde)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.secondary)
        }
    }
}
