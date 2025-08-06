import SwiftUI

struct SettingsCurrencySearchView: View {
    @Binding var selectedCurrency: String
    @Binding var isPresented: Bool
    @EnvironmentObject var appSettings: AppSettings
    
    @State private var searchText = ""
    
    // Para birimi gruplarını ayrı ayrı tanımla
    // Para birimi gruplarını ayrı ayrı tanımla
    private let majorCurrencies: [Currency] = [
        .USD,  // ABD Doları - English
        .EUR,  // Euro - German, Spanish, French, Italian
        .TRY,  // Türk Lirası - Turkish (3. sırada)
        .JPY,  // Japon Yeni - Japanese
        .CNY,  // Çin Yuanı - Chinese Simplified
        .INR,  // Hindistan Rupisi - Hindi
        .IDR,  // Endonezya Rupisi - Indonesian
        .MYR,  // Malezya Ringgiti - Malay
        .THB,  // Tayland Bahtı - Thai
        .VND,  // Vietnam Dongu - Vietnamese
        .GBP,  // İngiliz Sterlini - Önemli rezerv parası
        .CHF,  // İsviçre Frangı - Güvenli liman
        .CAD,  // Kanada Doları - G7
        .AUD,  // Avustralya Doları - Önemli
        .SGD   // Singapur Doları - Asya finans merkezi
    ]

    private let americasCurrencies: [Currency] = [
        .MXN, .BRL, .ARS, .CLP, .COP, .PEN, .UYU, .PYG, .BOB, .VES,
        .CRC, .GTQ, .HNL, .NIO, .PAB, .DOP, .JMD, .TTD, .BBD, .BSD, .HTG, .XCD
    ]

    private let europeCurrencies: [Currency] = [
        .SEK, .NOK, .DKK, .ISK, .PLN, .CZK, .HUF, .RON, .BGN, .HRK,
        .RSD, .MKD, .ALL, .BAM, .UAH, .BYN, .MDL, .GEL, .AMD, .AZN
    ]

    private let asiaCurrencies: [Currency] = [
        .KRW, .HKD, .TWD, .PHP, .BND, .PKR, .BDT, .LKR, .NPR,
        .MMK, .LAK, .KHR, .MNT, .BTN
    ]

    private let middleEastCurrencies: [Currency] = [
        .AED, .SAR, .QAR, .OMR, .BHD, .KWD, .JOD, .ILS, .EGP,
        .LBP, .SYP, .IQD, .YER, .IRR, .MAD, .TND, .DZD
    ]

    private let africaCurrencies: [Currency] = [
        .ZAR, .NGN, .KES, .UGX, .TZS, .ETB, .GHS, .XOF, .XAF,
        .MZN, .AOA, .MGA, .MUR, .SCR, .MVR
    ]

    private let oceaniaCurrencies: [Currency] = [
        .NZD, .FJD, .PGK, .SBD, .TOP, .VUV, .WST, .XPF
    ]

    private let otherCurrencies: [Currency] = [
        .RUB, .KZT, .UZS, .KGS, .TJS, .TMT, .AFN
    ]
    
    // Gruplandırılmış para birimleri
    private var groupedCurrencies: [(region: String, currencies: [Currency])] {
        let allGroups = [
            ("currency.region.major", majorCurrencies),
            ("currency.region.americas", americasCurrencies),
            ("currency.region.europe", europeCurrencies),
            ("currency.region.asia", asiaCurrencies),
            ("currency.region.middle_east", middleEastCurrencies),
            ("currency.region.africa", africaCurrencies),
            ("currency.region.oceania", oceaniaCurrencies),
            ("currency.region.others", otherCurrencies)
        ]
        
        // Arama aktifse filtrele
        if !searchText.isEmpty {
            let searchLower = searchText.lowercased()
            return allGroups.compactMap { group in
                let filtered = group.1.filter { currency in
                    // ISO kodunda ara
                    currency.rawValue.lowercased().contains(searchLower) ||
                    // Sembolde ara
                    currency.symbol.lowercased().contains(searchLower) ||
                    // Lokalize edilmiş isimde ara
                    getLocalizedCurrencyName(currency).lowercased().contains(searchLower)
                }
                return filtered.isEmpty ? nil : (group.0, filtered)
            }
        }
        
        return allGroups
    }
    
    // Yardımcı fonksiyon
    private func getLocalizedCurrencyName(_ currency: Currency) -> String {
        return NSLocalizedString(currency.localizedNameKey, comment: "")
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Arama alanı
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField(LocalizedStringKey("search.currency"), text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .submitLabel(.search)
                    
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                                .font(.system(size: 16))
                        }
                    }
                }
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding()
                
                // Para birimi listesi
                if groupedCurrencies.isEmpty {
                    // Arama sonucu bulunamadı
                    ContentUnavailableView(
                        "search.no_results",
                        systemImage: "magnifyingglass",
                        description: Text("search.no_results.description")
                    )
                } else {
                    List {
                        ForEach(groupedCurrencies, id: \.region) { group in
                            Section(header: Text(LocalizedStringKey(group.region))) {
                                ForEach(group.currencies, id: \.self) { currency in
                                    CurrencyRow(
                                        currency: currency,
                                        isSelected: selectedCurrency == currency.rawValue,
                                        onTap: {
                                            withAnimation(.spring()) {
                                                selectedCurrency = currency.rawValue
                                            }
                                            // Seçim yapıldıktan sonra kısa bir gecikmeyle kapat
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                                isPresented = false
                                            }
                                        }
                                    )
                                }
                            }
                        }
                    }
                    .listStyle(InsetGroupedListStyle())
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle(LocalizedStringKey("settings.select_currency"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(LocalizedStringKey("common.done")) {
                        isPresented = false
                    }
                    .fontWeight(.medium)
                }
            }
        }
    }
}

// Para birimi satırı
struct CurrencyRow: View {
    let currency: Currency
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Para birimi sembolü
                Text(currency.symbol)
                    .font(.title3)
                    .fontWeight(.medium)
                    .frame(width: 35, alignment: .center)
                    .foregroundColor(isSelected ? .white : .primary)
                
                // Para birimi bilgileri
                VStack(alignment: .leading, spacing: 2) {
                    Text(currency.rawValue)
                        .font(.headline)
                        .foregroundColor(isSelected ? .white : .primary)
                    
                    Text(LocalizedStringKey(currency.localizedNameKey))
                        .font(.caption)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                }
                
                Spacer()
                
                // Seçim göstergesi
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                        .font(.title3)
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.accentColor : Color.clear)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 2, trailing: 16))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }
}

// MARK: - Preview
#Preview {
    SettingsCurrencySearchView(
        selectedCurrency: .constant("TRY"),
        isPresented: .constant(true)
    )
    .environmentObject(AppSettings())
}
