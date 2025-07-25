import SwiftUI
import Charts

struct KategoriDetayView: View {
    let rapor: KategoriRaporVerisi
    @EnvironmentObject var appSettings: AppSettings
    @Environment(\.dismiss) private var dismiss
    
    @State private var secilenTab = 0
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Ana bilgiler
                    anaOzetKarti
                    
                    // Tab seçici
                    Picker("reports.category.detail_type", selection: $secilenTab) {
                        Text("reports.category.names").tag(0)
                        Text("reports.category.days").tag(1)
                        Text("reports.category.hours").tag(2)
                        Text("reports.category.trend").tag(3)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    // İçerik
                    switch secilenTab {
                    case 0:
                        isimlerDetayi
                    case 1:
                        gunlerDetayi
                    case 2:
                        saatlerDetayi
                    case 3:
                        trendDetayi
                    default:
                        EmptyView()
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle(LocalizedStringKey(rapor.kategori.localizationKey ?? rapor.kategori.isim))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("common.close") { dismiss() }
                }
            }
        }
    }
    
    @ViewBuilder
    private var anaOzetKarti: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: rapor.kategori.ikonAdi)
                    .font(.largeTitle)
                    .foregroundColor(rapor.kategori.renk)
                    .frame(width: 60, height: 60)
                    .background(rapor.kategori.renk.opacity(0.15))
                    .cornerRadius(12)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("reports.category.total_spending")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(formatCurrency(
                        amount: rapor.toplamTutar,
                        currencyCode: appSettings.currencyCode,
                        localeIdentifier: appSettings.languageCode
                    ))
                    .font(.title.bold())
                }
                
                Spacer()
            }
            
            HStack(spacing: 20) {
                metrikKutusu(
                    deger: "\(rapor.islemSayisi)",
                    baslik: "reports.category.transaction"
                )
                
                Divider()
                
                metrikKutusu(
                    deger: formatCurrency(
                        amount: rapor.ortalamaTutar,
                        currencyCode: appSettings.currencyCode,
                        localeIdentifier: appSettings.languageCode
                    ),
                    baslik: "reports.category.average"
                )
                
                Divider()
                
                metrikKutusu(
                    deger: formatCurrency(
                        amount: rapor.gunlukOrtalama,
                        currencyCode: appSettings.currencyCode,
                        localeIdentifier: appSettings.languageCode
                    ),
                    baslik: "reports.category.daily"
                )
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private func metrikKutusu(deger: String, baslik: LocalizedStringKey) -> some View {
        VStack {
            Text(deger)
                .font(.title2.bold())
            Text(baslik)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    @ViewBuilder
    private var isimlerDetayi: some View {
        let dilKodu = appSettings.languageCode
        let languageBundle: Bundle = {
            if let path = Bundle.main.path(forResource: dilKodu, ofType: "lproj"), let bundle = Bundle(path: path) {
                return bundle
            }
            return .main
        }()

        VStack(alignment: .leading, spacing: 16) {
            Text("reports.category.most_frequent_names")
                .font(.headline)
                .padding(.horizontal)
            
            ForEach(rapor.enSikKullanilanIsimler) { isimFrekansi in
                let kullanilmaSayisiMetni = String(
                    format: languageBundle.localizedString(forKey: "reports.category.used_times", value: "", table: nil),
                    isimFrekansi.frekans
                )
                let ortalamaMetni = String(
                    format: languageBundle.localizedString(forKey: "reports.category.avg_short_format", value: "", table: nil),
                    formatCurrency(
                        amount: isimFrekansi.ortalamatutar,
                        currencyCode: appSettings.currencyCode,
                        localeIdentifier: appSettings.languageCode
                    )
                )

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(isimFrekansi.isim)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text(kullanilmaSayisiMetni) // <--- Düzeltilmiş metin
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(formatCurrency(
                            amount: isimFrekansi.toplamTutar,
                            currencyCode: appSettings.currencyCode,
                            localeIdentifier: appSettings.languageCode
                        ))
                        .font(.subheadline.bold())
                        
                        Text(ortalamaMetni) // <--- Düzeltilmiş metin
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(8)
                .padding(.horizontal)
            }
        }
    }
    
    @ViewBuilder
    private var gunlerDetayi: some View {
        let dilKodu = appSettings.languageCode
        let languageBundle: Bundle = {
            if let path = Bundle.main.path(forResource: dilKodu, ofType: "lproj"), let bundle = Bundle(path: path) {
                return bundle
            }
            return .main
        }()

        VStack(alignment: .leading, spacing: 16) {
            Text("reports.category.distribution_by_days")
                .font(.headline)
                .padding(.horizontal)
            
            Chart(rapor.gunlereGoreDagilim) { gun in
                BarMark(
                    x: .value("Day", gun.gunAdi),
                    y: .value("Amount", gun.tutar)
                )
                .foregroundStyle(rapor.kategori.renk)
                .cornerRadius(4)
            }
            .frame(height: 200)
            .padding(.horizontal)
            
            ForEach(rapor.gunlereGoreDagilim) { gun in
                let islemSayisiMetni = String(
                    format: languageBundle.localizedString(forKey: "reports.category.transaction_count", value: "", table: nil),
                    gun.islemSayisi
                )

                HStack {
                    Text(gun.gunAdi)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(formatCurrency(
                            amount: gun.tutar,
                            currencyCode: appSettings.currencyCode,
                            localeIdentifier: appSettings.languageCode
                        ))
                        .fontWeight(.semibold)
                        
                        Text(islemSayisiMetni) // <--- Düzeltilmiş metin
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private var saatlerDetayi: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("reports.category.distribution_by_hours")
                .font(.headline)
                .padding(.horizontal)
            
            RadyalSaatGrafigi(
                saatlikDagilim: rapor.saatlereGoreDagilim.map { saatlik in
                    SaatlikDagilimVerisi(
                        saat: saatlik.saat,
                        toplamTutar: saatlik.tutar,
                        islemSayisi: saatlik.islemSayisi,
                        yuzde: 0
                    )
                }
            )
            .environmentObject(appSettings)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private var trendDetayi: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("reports.category.monthly_trend")
                .font(.headline)
                .padding(.horizontal)
            
            if !rapor.aylikTrend.isEmpty {
                Chart(rapor.aylikTrend) { nokta in
                    LineMark(
                        x: .value("Month", nokta.ay),
                        y: .value("Amount", nokta.tutar)
                    )
                    .foregroundStyle(rapor.kategori.renk)
                    .interpolationMethod(.catmullRom)
                    
                    PointMark(
                        x: .value("Month", nokta.ay),
                        y: .value("Amount", nokta.tutar)
                    )
                    .foregroundStyle(rapor.kategori.renk)
                    .symbolSize(100)
                }
                .frame(height: 200)
                .padding(.horizontal)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}
