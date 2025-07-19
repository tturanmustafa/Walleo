import SwiftUI

struct KategoriListeKarti: View {
    let rapor: KategoriRaporVerisi
    let onTap: () -> Void
    @EnvironmentObject var appSettings: AppSettings
    
    var body: some View {
        // 1. AppSettings'e göre doğru dil paketini (bundle) manuel olarak bulalım.
        let languageBundle: Bundle = {
            let langCode = appSettings.languageCode
            // Dil koduna uygun .lproj klasörünün yolunu bul
            if let path = Bundle.main.path(forResource: langCode, ofType: "lproj"),
               let bundle = Bundle(path: path) {
                return bundle
            }
            // Eğer bulunamazsa, varsayılan (genellikle İngilizce) paketi kullan
            return .main
        }()
        
        // 2. Bulduğumuz dil paketini kullanarak metinleri oluşturalım.
        let islemSayisiMetni = String(
            format: languageBundle.localizedString(forKey: "reports.category.transaction_count", value: "", table: nil),
            rapor.islemSayisi
        )

        let gunlukOrtalamaMetni = String(
            format: languageBundle.localizedString(forKey: "reports.category.daily_average_format", value: "", table: nil),
            formatCurrency(
                amount: rapor.gunlukOrtalama,
                currencyCode: appSettings.currencyCode,
                localeIdentifier: appSettings.languageCode
            )
        )
        
        // 3. View'da bu hazır metinleri kullanalım.
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Başlık
                HStack {
                    Image(systemName: rapor.kategori.ikonAdi)
                        .font(.title2)
                        .foregroundColor(rapor.kategori.renk)
                        .frame(width: 40, height: 40)
                        .background(rapor.kategori.renk.opacity(0.15))
                        .cornerRadius(8)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(LocalizedStringKey(rapor.kategori.localizationKey ?? rapor.kategori.isim))
                            .font(.headline)
                        
                        // "2 işlem" sorununu çözen satır
                        Text(islemSayisiMetni)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(formatCurrency(
                            amount: rapor.toplamTutar,
                            currencyCode: appSettings.currencyCode,
                            localeIdentifier: appSettings.languageCode
                        ))
                        .font(.headline.bold())
                        
                        // "/gün" sorununu çözen satır
                        Text(gunlukOrtalamaMetni)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                }
                
                // Mini trend grafiği
                if !rapor.aylikTrend.isEmpty {
                    MiniTrendChart(data: rapor.aylikTrend, color: rapor.kategori.renk)
                        .frame(height: 40)
                }
                
                // En sık kullanılan isimler
                if !rapor.enSikKullanilanIsimler.isEmpty {
                    HStack {
                        Image(systemName: "tag.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(rapor.enSikKullanilanIsimler.prefix(3).map { $0.isim }.joined(separator: ", "))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
        }
        .buttonStyle(.plain)
    }
}

// Mini trend grafiği (Bu kısım aynı kalacak)
struct MiniTrendChart: View {
    let data: [AylikTrendNokta]
    let color: Color
    
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                guard !data.isEmpty else { return }
                
                let maxValue = data.map { $0.tutar }.max() ?? 1
                let minValue = data.map { $0.tutar }.min() ?? 0
                let range = maxValue - minValue
                
                for (index, nokta) in data.enumerated() {
                    let x = geometry.size.width * CGFloat(index) / CGFloat(max(data.count - 1, 1))
                    let normalizedValue = range > 0 ? (nokta.tutar - minValue) / range : 0.5
                    let y = geometry.size.height * (1 - normalizedValue)
                    
                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(color, lineWidth: 2)
        }
    }
}
