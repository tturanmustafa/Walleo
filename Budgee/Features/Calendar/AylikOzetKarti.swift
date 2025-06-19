import SwiftUI

struct AylikOzetKarti: View {
    @EnvironmentObject var appSettings: AppSettings
    let gelir: Double
    let gider: Double
    let net: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // DEĞİŞİKLİK: Sabit metin yerine çeviri anahtarı kullanılıyor.
            Text("calendar.monthly_summary")
                .font(.headline)
                .fontWeight(.bold)
                
            HStack(spacing: 15) {
                Menu {
                    Text(formatCurrency(amount: gelir, currencyCode: appSettings.currencyCode, localeIdentifier: appSettings.languageCode))
                } label: {
                    // DEĞİŞİKLİK: Sabit metin yerine çeviri anahtarı kullanılıyor.
                    OzetSatiri(renk: .green, baslik: "common.income", tutar: gelir)
                }
                .buttonStyle(.plain)

                Menu {
                    Text(formatCurrency(amount: gider, currencyCode: appSettings.currencyCode, localeIdentifier: appSettings.languageCode))
                } label: {
                    // DEĞİŞİKLİK: Sabit metin yerine çeviri anahtarı kullanılıyor.
                    OzetSatiri(renk: .red, baslik: "common.expense", tutar: gider)
                }
                .buttonStyle(.plain)

                Menu {
                    Text(formatCurrency(amount: net, currencyCode: appSettings.currencyCode, localeIdentifier: appSettings.languageCode))
                } label: {
                    // DEĞİŞİKLİK: Sabit metin yerine çeviri anahtarı kullanılıyor.
                    OzetSatiri(renk: net >= 0 ? .blue : .orange, baslik: "common.net", tutar: net)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.7))
        .cornerRadius(12)
    }
}

// Aylık Özet Kartı içindeki her bir satır için yardımcı View
private struct OzetSatiri: View {
    @EnvironmentObject var appSettings: AppSettings
    let renk: Color
    // DEĞİŞİKLİK: 'baslik' artık bir String değil, LocalizedStringKey.
    let baslik: LocalizedStringKey
    let tutar: Double
    
    var body: some View {
        HStack {
            Circle().fill(renk).frame(width: 8, height: 8)
            VStack(alignment: .leading) {
                // DEĞİŞİKLİK: Text artık anahtarı doğrudan kullanarak çeviriyi kendisi yapıyor.
                Text(baslik)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(formatCurrency(amount: tutar, currencyCode: appSettings.currencyCode, localeIdentifier: appSettings.languageCode))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
            }
            Spacer()
        }
        .contentShape(Rectangle())
    }
}
