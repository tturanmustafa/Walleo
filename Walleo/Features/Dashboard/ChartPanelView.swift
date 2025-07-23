import SwiftUI
import Charts

struct ChartPanelView: View {
    let pieChartVerisi: [KategoriHarcamasi]
    let kategoriDetaylari: [String: (renk: Color, ikon: String)]
    let toplamTutar: Double
    
    // YENİ: Genişletilmiş görünüm state'i
    @State private var isExpanded = false
    
    // YENİ: Görüntülenecek kategori sayısı
    private var displayedCategories: [KategoriHarcamasi] {
        if isExpanded {
            return pieChartVerisi
        } else {
            return Array(pieChartVerisi.prefix(4))
        }
    }
    
    // YENİ: Gizli kategori sayısı
    private var hiddenCategoriesCount: Int {
        max(0, pieChartVerisi.count - 4)
    }

    var body: some View {
        if !pieChartVerisi.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                Text("dashboard.category_distribution")
                    .font(.headline)
                    .fontWeight(.bold)
                    .padding([.top, .leading, .trailing])
                    .padding(.bottom, 14)
                
                HStack(alignment: .top, spacing: 15) {
                    // Chart - tüm kategorileri göster
                    chartView
                        .frame(width: 140, height: 140)
                    
                    // YENİ: Genişletilebilir kategori listesi
                    expandableCategoryListView
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.trailing)
                }
                .padding([.leading, .bottom])
            }
            .background(Color(.systemGray6).opacity(0.4))
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }
    
    // Chart'ı ayrı view'a çıkar
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
        .animation(.easeInOut(duration: 0.5), value: pieChartVerisi.map { $0.tutar })
    }
    
    // YENİ: Genişletilebilir kategori listesi
    @ViewBuilder
    private var expandableCategoryListView: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Görünen kategoriler
            ForEach(displayedCategories) { veri in
                CategoryRowView(
                    veri: veri,
                    yuzde: calculatePercentage(for: veri.tutar),
                    ikon: veri.ikonAdi
                )
            }
            
            // Genişlet/Daralt butonu
            if hiddenCategoriesCount > 0 {
                Button(action: { withAnimation(.spring()) { isExpanded.toggle() } }) {
                    HStack(spacing: 6) {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                        
                        if isExpanded {
                            Text("dashboard.show_less")
                                .font(.callout)
                                .fontWeight(.medium)
                        } else {
                            Text("+\(hiddenCategoriesCount) ")
                                .font(.callout)
                                .fontWeight(.medium)
                            + Text("dashboard.more_categories")
                                .font(.callout)
                                .fontWeight(.medium)
                        }
                        
                        Spacer()
                    }
                    .foregroundColor(.accentColor)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.top, 4)
            }
        }
    }
    
    // YENİ: Yüzde hesaplama helper fonksiyonu
    private func calculatePercentage(for amount: Double) -> String {
        let yuzde = toplamTutar > 0 ? (amount / toplamTutar) * 100 : 0
        return String(format: "%.1f%%", yuzde)
    }
}

// Kategori satırını ayrı struct'a çıkar
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
