import SwiftUI

struct IstatistiklerCard: View {
    let baslikKey: LocalizedStringKey
    let ozetVerisi: OzetVerisi
    @EnvironmentObject var appSettings: AppSettings
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(baslikKey)
                .font(.headline)
                .foregroundStyle(.secondary)

            VStack(spacing: 16) {
                // Günlük Ortalama Gelir
                IstatistikSatiri(
                    labelKey: "reports.statistics.daily_avg_income",
                    value: formatCurrency(
                        amount: ozetVerisi.gunlukOrtalamaGelir,
                        currencyCode: appSettings.currencyCode,
                        localeIdentifier: appSettings.languageCode
                    ),
                    iconName: "calendar.day.timeline.leading",
                    iconColor: .green
                )
                
                Divider()

                // Günlük Ortalama Gider
                IstatistikSatiri(
                    labelKey: "reports.statistics.daily_avg_expense",
                    value: formatCurrency(
                        amount: ozetVerisi.gunlukOrtalamaHarcama,
                        currencyCode: appSettings.currencyCode,
                        localeIdentifier: appSettings.languageCode
                    ),
                    iconName: "calendar.day.timeline.trailing",
                    iconColor: .red
                )

                // En Yüksek Tekil Gelir
                if let enYuksekGelir = ozetVerisi.enYuksekGelir {
                    Divider()
                    IstatistikSatiri(
                        labelKey: "reports.statistics.highest_income",
                        value: formatCurrency(
                            amount: enYuksekGelir.tutar,
                            currencyCode: appSettings.currencyCode,
                            localeIdentifier: appSettings.languageCode
                        ) + " (\(enYuksekGelir.isim))",
                        iconName: "arrow.up.circle.fill",
                        iconColor: .green.opacity(0.8)
                    )
                }
                
                // En Yüksek Tekil Gider
                if let enYuksekHarcama = ozetVerisi.enYuksekHarcama {
                    Divider()
                    IstatistikSatiri(
                        labelKey: "reports.statistics.highest_expense",
                        value: formatCurrency(
                            amount: enYuksekHarcama.tutar,
                            currencyCode: appSettings.currencyCode,
                            localeIdentifier: appSettings.languageCode
                        ) + " (\(enYuksekHarcama.isim))",
                        iconName: "arrow.down.circle.fill",
                        iconColor: .red.opacity(0.8)
                    )
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, y: 5)
    }
}

private struct IstatistikSatiri: View {
    let labelKey: LocalizedStringKey
    let value: String
    let iconName: String
    let iconColor: Color

    var body: some View {
        HStack {
            Image(systemName: iconName)
                .font(.title3)
                .foregroundColor(iconColor)
                .frame(width: 30)

            VStack(alignment: .leading) {
                // Label artık .strings dosyasından geliyor.
                Text(labelKey)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.callout)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer()
        }
    }
}
