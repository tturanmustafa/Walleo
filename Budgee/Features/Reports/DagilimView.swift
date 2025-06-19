import SwiftUI
import Charts

struct DagilimView: View {
    @Bindable var viewModel: RaporlarViewModel
    @EnvironmentObject var appSettings: AppSettings
    
    @State private var secilenTur: IslemTuru = .gider

    private var seciliVeri: [KategoriOzetSatiri] {
        secilenTur == .gider ? viewModel.giderDagilimVerisi : viewModel.gelirDagilimVerisi
    }
    
    private var seciliToplamTutar: Double {
        secilenTur == .gider ? viewModel.ozetVerisi.toplamGider : viewModel.ozetVerisi.toplamGelir
    }

    var body: some View {
        VStack {
            Picker("Dağılım Türü", selection: $secilenTur.animation()) {
                Text(LocalizedStringKey("common.expense")).tag(IslemTuru.gider)
                Text(LocalizedStringKey("common.income")).tag(IslemTuru.gelir)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            if seciliVeri.isEmpty {
                ContentUnavailableView(
                    LocalizedStringKey("reports.distribution.no_data"),
                    systemImage: "chart.pie.fill"
                )
            } else {
                ScrollView {
                    VStack(spacing: 20) {
                        VStack {
                            // GRAFİK DÜZENLEMESİ
                            Chart(seciliVeri) { veri in
                                SectorMark(
                                    angle: .value("Tutar", veri.tutar),
                                    innerRadius: .ratio(0.6),
                                    angularInset: 2.0 // Dashboard ile aynı
                                )
                                .foregroundStyle(veri.renk)
                                .cornerRadius(8) // Dashboard ile aynı
                                // Gölge eklendi (Dashboard ile aynı)
                                .shadow(color: .black.opacity(0.3), radius: 2, x: 2, y: 2)
                            }
                            // Frame düzenlendi (Dashboard gibi kare)
                            .frame(width: 250, height: 250)
                            .chartBackground { chartProxy in
                                GeometryReader { geometry in
                                    let frame = geometry[chartProxy.plotAreaFrame]
                                    VStack {
                                        // ORTA METİN DÜZENLEMESİ
                                        Text(LocalizedStringKey("common.total"))
                                            .font(.callout)
                                            .foregroundStyle(.secondary)
                                        Text(formatCurrency(amount: seciliToplamTutar, currencyCode: appSettings.currencyCode, localeIdentifier: appSettings.languageCode))
                                            .font(.title2.bold())
                                    }
                                    .position(x: frame.midX, y: frame.midY)
                                }
                            }
                        }
                        .padding(.vertical)
                        
                        VStack(spacing: 12) {
                            ForEach(seciliVeri) { kategori in
                                DagilimSatiriView(kategori: kategori)
                            }
                        }
                    }
                    .padding()
                }
            }
        }
    }
}

struct DagilimSatiriView: View {
    let kategori: KategoriOzetSatiri
    @EnvironmentObject var appSettings: AppSettings

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: kategori.ikonAdi)
                .font(.callout)
                .foregroundColor(.white)
                .frame(width: 38, height: 38)
                .background(kategori.renk)
                .cornerRadius(8)
            VStack(alignment: .leading) {
                Text(LocalizedStringKey(kategori.kategoriAdi))
                    .fontWeight(.semibold)
                Text(String(format: "%.1f%%", kategori.yuzde))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(formatCurrency(
                amount: kategori.tutar,
                currencyCode: appSettings.currencyCode,
                localeIdentifier: appSettings.languageCode
            ))
            .font(.body.bold())
        }
    }
}
