import SwiftUI

struct KarsilastirmaCard: View {
    let karsilastirmaVerisi: KarsilastirmaVerisi
    @EnvironmentObject var appSettings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(LocalizedStringKey("reports.summary.card.comparison"))
                .font(.headline)
                .foregroundStyle(.secondary)
            
            if karsilastirmaVerisi.giderDegisimYuzdesi == nil && karsilastirmaVerisi.netAkisFarki == nil {
                Text(LocalizedStringKey("reports.comparison.no_data"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                // Net Akış Karşılaştırmasıx
                if let netAkisFarki = karsilastirmaVerisi.netAkisFarki {
                    let isPositive = netAkisFarki >= 0
                    let formattedFark = formatCurrency(
                        amount: abs(netAkisFarki),
                        currencyCode: appSettings.currencyCode,
                        localeIdentifier: appSettings.languageCode
                    )
                    
                    let prefixKey = isPositive ? "reports.comparison.prefix_net_flow_positive" : "reports.comparison.prefix_net_flow_negative"
                    let suffixKey = isPositive ? "reports.comparison.suffix_net_flow_positive" : "reports.comparison.suffix_net_flow_negative"
                    
                    KarsilastirmaSatiri(
                        prefixKey: prefixKey,
                        argument: formattedFark,
                        suffixKey: suffixKey,
                        iconName: isPositive ? "arrow.up.right" : "arrow.down.right",
                        color: isPositive ? .green : .orange
                    )
                }
                
                // Gider Karşılaştırması
                if let giderDegisimYuzdesi = karsilastirmaVerisi.giderDegisimYuzdesi, giderDegisimYuzdesi != 0 {
                    let isPositive = giderDegisimYuzdesi > 0
                    let formattedYuzde = String(format: "%%%.1f", abs(giderDegisimYuzdesi))

                    let prefixKey = isPositive ? "reports.comparison.prefix_expenses_increased" : "reports.comparison.prefix_expenses_decreased"
                    let suffixKey = isPositive ? "reports.comparison.suffix_expenses_increased" : "reports.comparison.suffix_expenses_decreased"
                    
                    KarsilastirmaSatiri(
                        prefixKey: prefixKey,
                        argument: formattedYuzde,
                        suffixKey: suffixKey,
                        iconName: isPositive ? "arrow.up.right" : "arrow.down.right",
                        color: isPositive ? .red : .green
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

private struct KarsilastirmaSatiri: View {
    let prefixKey: String
    let argument: String
    let suffixKey: String
    let iconName: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.callout.bold())
                .foregroundColor(color)
                .frame(width: 20)
            
            // NİHAİ ÇÖZÜM: Üç ayrı Text'i birleştiriyoruz.
            // Bu yöntem, her parçanın lokalizasyonunun SwiftUI tarafından doğru yapılmasını sağlar.
            (
                Text(LocalizedStringKey(prefixKey)) +
                Text(argument).fontWeight(.bold) +
                Text(LocalizedStringKey(suffixKey))
            )
            .font(.callout)
            .multilineTextAlignment(.leading)
            
            Spacer()
        }
    }
}
