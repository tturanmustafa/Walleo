import SwiftUI
import Charts

struct DagilimView<ViewModel: RaporViewModelProtocol>: View {
    let viewModel: ViewModel
    @EnvironmentObject var appSettings: AppSettings
    
    @State private var secilenTur: IslemTuru = .gider

    private var seciliVeri: [KategoriOzetSatiri] {
        secilenTur == .gider ? viewModel.giderDagilimVerisi : viewModel.gelirDagilimVerisi
    }
    
    private var seciliToplamTutar: Double {
        secilenTur == .gider ? viewModel.ozetVerisi.toplamGider : viewModel.ozetVerisi.toplamGelir
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Dağılım Türü", selection: $secilenTur.animation()) {
                Text(LocalizedStringKey("common.expense")).tag(IslemTuru.gider)
                Text(LocalizedStringKey("common.income")).tag(IslemTuru.gelir)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            // GÜNCELLEME: Picker ile altındaki içerik arasına boşluk eklendi.
            .padding(.bottom, 20)

            if seciliVeri.isEmpty {
                ContentUnavailableView(
                    LocalizedStringKey("reports.distribution.no_data"),
                    systemImage: "chart.pie.fill"
                )
            } else {
                ScrollView {
                    VStack(spacing: 20) {
                        VStack {
                            Chart(seciliVeri) { veri in
                                SectorMark(
                                    angle: .value("Tutar", veri.tutar),
                                    innerRadius: .ratio(0.6),
                                    angularInset: 2.0
                                )
                                .foregroundStyle(veri.renk)
                                .cornerRadius(8)
                                .shadow(color: .black.opacity(0.3), radius: 2, x: 2, y: 2)
                            }
                            .frame(width: 250, height: 250)
                            .chartBackground { chartProxy in
                                GeometryReader { geometry in
                                    if let anchor = chartProxy.plotFrame {
                                        let frame = geometry[anchor]

                                        VStack {
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
                        }
                        .padding(.vertical)
                        
                        VStack(spacing: 12) {
                            ForEach(seciliVeri) { kategori in
                                DagilimSatiriView(kategori: kategori)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .padding(.top)
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
