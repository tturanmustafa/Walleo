// Walleo/Features/ReportsDetailed/Views/KrediKartiRaporuView.swift

import SwiftUI
import SwiftData
import Charts

struct KrediKartiRaporuView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: KrediKartiRaporuViewModel
    @EnvironmentObject var appSettings: AppSettings

    let baslangicTarihi: Date
    let bitisTarihi: Date
    
    @State private var acikPaneller: Set<UUID> = []
    @State private var secilenKartIndex = 0
    @State private var gosterimModu: GosterimModu = .detay
    
    enum GosterimModu: String, CaseIterable {
        case detay = "reports.creditcard.detail_view"
        case karsilastirma = "reports.creditcard.comparison_view"
        case ozet = "reports.creditcard.summary_view"
    }

    init(modelContext: ModelContext, baslangicTarihi: Date, bitisTarihi: Date) {
        self.baslangicTarihi = baslangicTarihi
        self.bitisTarihi = bitisTarihi
        _viewModel = State(initialValue: KrediKartiRaporuViewModel(
            modelContext: modelContext,
            baslangicTarihi: baslangicTarihi,
            bitisTarihi: bitisTarihi
        ))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if viewModel.isLoading {
                    ProgressView(LocalizedStringKey("common.loading"))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.top, 100)
                } else if viewModel.kartDetayRaporlari.isEmpty {
                    ContentUnavailableView(
                        LocalizedStringKey("reports.creditcard.no_data"),
                        systemImage: "creditcard.fill",
                        description: Text(LocalizedStringKey("reports.creditcard.no_data_desc"))
                    )
                    .padding(.top, 100)
                } else {
                    // Geliştirilmiş genel özet
                    GelismisGenelOzetKarti(ozet: viewModel.genelOzet)
                        .padding(.horizontal)
                    
                    // Gösterim modu seçici
                    Picker("", selection: $gosterimModu) {
                        ForEach(GosterimModu.allCases, id: \.self) { mod in
                            Text(LocalizedStringKey(mod.rawValue)).tag(mod)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    switch gosterimModu {
                    case .detay:
                        detayliGorunum
                    case .karsilastirma:
                        karsilastirmaGorunumu
                    case .ozet:
                        ozetGorunum
                    }
                }
            }
            .padding(.vertical)
        }
        .onAppear { Task { await viewModel.fetchData() } }
        .onChange(of: baslangicTarihi) {
            viewModel.baslangicTarihi = baslangicTarihi
            viewModel.bitisTarihi = bitisTarihi
            Task { await viewModel.fetchData() }
        }
        .onChange(of: bitisTarihi) {
            viewModel.baslangicTarihi = baslangicTarihi
            viewModel.bitisTarihi = bitisTarihi
            Task { await viewModel.fetchData() }
        }
    }
    
    // MARK: - Detaylı Görünüm
    @ViewBuilder
    private var detayliGorunum: some View {
        VStack(spacing: 16) {
            // Kart seçici
            // Kart seçici
            if viewModel.kartDetayRaporlari.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(viewModel.kartDetayRaporlari.enumerated()), id: \.element.id) { index, rapor in
                            KartSeciciView(
                                rapor: rapor,
                                isSelected: secilenKartIndex == index,
                                onTap: {
                                    withAnimation(.spring(response: 0.3)) {
                                        secilenKartIndex = index
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 4)
                }
                .frame(height: 95) // Yükseklik azaltıldı
            }
            
            if let secilenRapor = viewModel.kartDetayRaporlari[safe: secilenKartIndex] {
                // Ana kart detay paneli
                GelismisKartDetayPaneli(rapor: secilenRapor)
                    .padding(.horizontal)
                
                // Kategori analizi
                KategoriAnaliziView(rapor: secilenRapor)
                    .padding(.horizontal)
                
                // Harcama trendi
                GelismisHarcamaTrendiView(rapor: secilenRapor)
                    .padding(.horizontal)
                
                // Taksitli işlemler özeti
                if secilenRapor.taksitliIslemler.count > 0 {
                    TaksitliIslemlerOzetiView(taksitliIslemler: secilenRapor.taksitliIslemler)
                        .padding(.horizontal)
                }
            }
        }
    }
    
    // MARK: - Karşılaştırma Görünümü
    @ViewBuilder
    private var karsilastirmaGorunumu: some View {
        VStack(spacing: 20) {
            // Kartlar arası karşılaştırma grafiği
            KartlarArasiKarsilastirmaView(raporlar: viewModel.kartDetayRaporlari)
                .padding(.horizontal)
            
            // Kompakt kart listesi
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(viewModel.kartDetayRaporlari) { rapor in
                        KompaktKartView(rapor: rapor)
                    }
                }
                .padding(.horizontal)
            }
            
            // Detaylı karşılaştırma tablosu
            KarsilastirmaTablosuView(raporlar: viewModel.kartDetayRaporlari)
                .padding(.horizontal)
        }
    }
    
    // MARK: - Özet Görünüm
    @ViewBuilder
    private var ozetGorunum: some View {
        VStack(spacing: 20) {
            // Kart listesi - yatay kaydırmalı
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(viewModel.kartDetayRaporlari) { rapor in
                        KompaktKartView(rapor: rapor)
                    }
                }
                .padding(.horizontal)
            }
            
            // Toplam harcama dağılımı
            ToplamHarcamaDagilimiView(raporlar: viewModel.kartDetayRaporlari)
                .padding(.horizontal)
            
            // Kategori bazlı toplam analiz
            ToplamKategoriAnaliziView(raporlar: viewModel.kartDetayRaporlari)
                .padding(.horizontal)
            
            // Günlük ortalamalar
            GunlukOrtalamaAnaliziView(raporlar: viewModel.kartDetayRaporlari)
                .padding(.horizontal)
        }
    }
}

// MARK: - Gelişmiş Genel Özet Kartı
struct GelismisGenelOzetKarti: View {
    let ozet: KrediKartiGenelOzet
    @EnvironmentObject var appSettings: AppSettings
    @State private var animateValues = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Başlık ve toplam harcama
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("reports.creditcard.total_spending")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text(formatCurrency(
                        amount: ozet.toplamHarcama,
                        currencyCode: appSettings.currencyCode,
                        localeIdentifier: appSettings.languageCode
                    ))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .opacity(animateValues ? 1 : 0)
                    .animation(.spring(response: 0.6), value: animateValues)
                }
                
                Spacer()
                
                // Büyüme göstergesi
                VStack(alignment: .trailing, spacing: 4) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.title2)
                        .foregroundColor(.blue)
                    
                    if let degisimYuzdesi = ozet.oncekiDonemeDegisimYuzdesi {
                        HStack(spacing: 4) {
                            Image(systemName: degisimYuzdesi > 0 ? "arrow.up" : "arrow.down")
                                .font(.caption)
                            Text(String(format: "%.1f%%", abs(degisimYuzdesi)))
                                .font(.caption.bold())
                        }
                        .foregroundColor(degisimYuzdesi > 0 ? .red : .green)
                    }
                }
            }
            
            // Ana metrikler
            HStack(spacing: 16) {
                MetrikKutusu(
                    ikon: "creditcard.fill",
                    baslik: "reports.creditcard.active_cards",
                    deger: "\(ozet.aktifKartSayisi)",
                    renk: .blue
                )
                
                MetrikKutusu(
                    ikon: "number.circle.fill",
                    baslik: "reports.creditcard.transactions",
                    deger: "\(ozet.islemSayisi)",
                    renk: .green
                )
                
                MetrikKutusu(
                    ikon: "calendar",
                    baslik: "reports.creditcard.daily_avg",
                    deger: formatCurrency(
                        amount: ozet.gunlukOrtalama,
                        currencyCode: appSettings.currencyCode,
                        localeIdentifier: appSettings.languageCode
                    ),
                    renk: .orange
                )
            }
            
            // En çok kullanılan kart
            if let enCokKullanilanKart = ozet.enCokKullanilanKart {
                HStack {
                    Image(systemName: "star.circle.fill")
                        .font(.title3)
                        .foregroundColor(.yellow)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("reports.creditcard.most_used")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(enCokKullanilanKart.isim)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    
                    Spacer()
                    
                    if let kullanımOrani = ozet.enCokKullanilanKartKullanimOrani {
                        Text(String(format: "%.0f%%", kullanımOrani))
                            .font(.headline.bold())
                            .foregroundColor(.accentColor)
                    }
                }
                .padding()
                .background(Color(.tertiarySystemGroupedBackground))
                .cornerRadius(12)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
        .onAppear { animateValues = true }
    }
}

// MARK: - Kart Seçici View
struct KartSeciciView: View {
    let rapor: KartDetayRaporu
    let isSelected: Bool
    let onTap: () -> Void
    @EnvironmentObject var appSettings: AppSettings
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                // Üst kısım - İkon ve hesap adı
                HStack(spacing: 8) {
                    Image(systemName: rapor.hesap.ikonAdi)
                        .font(.title3)
                        .foregroundColor(rapor.hesap.renk)
                        .frame(width: 32, height: 32)
                        .background(rapor.hesap.renk.opacity(0.15))
                        .cornerRadius(8)
                    
                    Text(rapor.hesap.isim)
                        .font(.subheadline)
                        .fontWeight(isSelected ? .semibold : .regular)
                        .lineLimit(1)
                    
                    Spacer()
                }
                
                // Harcama tutarı
                HStack {
                    Text(formatCurrency(
                        amount: rapor.toplamHarcama,
                        currencyCode: appSettings.currencyCode,
                        localeIdentifier: appSettings.languageCode
                    ))
                    .font(.footnote.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    
                    Spacer()
                }
                
                // Kullanım yüzdesi ve progress bar
                if let dolulukOrani = rapor.kartDolulukOrani {
                    VStack(spacing: 4) {
                        HStack {
                            Text(String(format: "%.0f%%", dolulukOrani))
                                .font(.caption2.bold())
                                .foregroundColor(
                                    dolulukOrani > 80 ? .red :
                                    dolulukOrani > 60 ? .orange : .green
                                )
                            
                            Spacer()
                            
                            Text("reports.creditcard.usage.short")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        
                        ProgressView(value: dolulukOrani, total: 100)
                            .tint(
                                dolulukOrani > 80 ? .red :
                                dolulukOrani > 60 ? .orange : .green
                            )
                            .scaleEffect(x: 1, y: 0.5, anchor: .center)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(width: 160, height: 85)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.accentColor.opacity(0.1) : Color(.tertiarySystemGroupedBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Gelişmiş Kart Detay Paneli
struct GelismisKartDetayPaneli: View {
    let rapor: KartDetayRaporu
    @EnvironmentObject var appSettings: AppSettings
    @State private var expandMetrics = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Kart başlığı ve limit bilgisi
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: rapor.hesap.ikonAdi)
                    .font(.title2)
                    .foregroundColor(rapor.hesap.renk)
                    .frame(width: 50, height: 50)
                    .background(rapor.hesap.renk.opacity(0.15))
                    .cornerRadius(12)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(rapor.hesap.isim)
                        .font(.title3)
                        .fontWeight(.bold)
                    
                    if let limit = rapor.kartLimiti {
                        HStack(spacing: 4) {
                            Text("reports.creditcard.limit")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            Text(formatCurrency(
                                amount: limit,
                                currencyCode: appSettings.currencyCode,
                                localeIdentifier: appSettings.languageCode
                            ))
                            .font(.caption)
                            .fontWeight(.medium)
                        }
                    }
                }
                
                Spacer()
                
                // Doluluk oranı
                if let dolulukOrani = rapor.kartDolulukOrani {
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                                .frame(width: 70, height: 70)
                            
                            Circle()
                                .trim(from: 0, to: dolulukOrani / 100)
                                .stroke(
                                    dolulukOrani > 80 ? Color.red :
                                    dolulukOrani > 60 ? Color.orange : Color.green,
                                    lineWidth: 8
                                )
                                .rotationEffect(.degrees(-90))
                                .frame(width: 70, height: 70)
                            
                            Text(String(format: "%.0f%%", dolulukOrani))
                                .font(.headline.bold())
                        }
                        
                        Text("reports.creditcard.usage")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            // Detaylı metrikler
            Button(action: { withAnimation { expandMetrics.toggle() } }) {
                HStack {
                    Text(expandMetrics ? "reports.creditcard.hide_metrics" : "reports.creditcard.show_metrics")
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Image(systemName: expandMetrics ? "chevron.up" : "chevron.down")
                        .font(.caption)
                }
                .foregroundColor(.accentColor)
            }
            
            if expandMetrics {
                VStack(spacing: 12) {
                    HStack(spacing: 16) {
                        DetailMetrik(
                            baslik: "reports.creditcard.current_debt",
                            deger: formatCurrency(
                                amount: rapor.guncelBorc ?? 0,
                                currencyCode: appSettings.currencyCode,
                                localeIdentifier: appSettings.languageCode
                            ),
                            ikon: "creditcard.trianglebadge.exclamationmark",
                            renk: .red
                        )
                        
                        DetailMetrik(
                            baslik: "reports.creditcard.available",
                            deger: formatCurrency(
                                amount: rapor.kullanilabilirLimit ?? 0,
                                currencyCode: appSettings.currencyCode,
                                localeIdentifier: appSettings.languageCode
                            ),
                            ikon: "checkmark.circle",
                            renk: .green
                        )
                    }
                    
                    HStack(spacing: 16) {
                        DetailMetrik(
                            baslik: "reports.creditcard.highest_day",
                            deger: formatCurrency(
                                amount: rapor.enYuksekGunlukHarcama ?? 0,
                                currencyCode: appSettings.currencyCode,
                                localeIdentifier: appSettings.languageCode
                            ),
                            ikon: "arrow.up.circle",
                            renk: .orange
                        )
                        
                        DetailMetrik(
                            baslik: "reports.creditcard.avg_transaction",
                            deger: formatCurrency(
                                amount: rapor.ortalamaIslemTutari ?? 0,
                                currencyCode: appSettings.currencyCode,
                                localeIdentifier: appSettings.languageCode
                            ),
                            ikon: "equal.circle",
                            renk: .blue
                        )
                    }
                }
                .transition(.asymmetric(
                    insertion: .scale.combined(with: .opacity),
                    removal: .scale.combined(with: .opacity)
                ))
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
}

// MARK: - Yardımcı View'lar
struct MetrikKutusu: View {
    let ikon: String
    let baslik: LocalizedStringKey
    let deger: String
    let renk: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: ikon)
                .font(.title2)
                .foregroundColor(renk)
            
            Text(baslik)
                .font(.caption2)
                .foregroundStyle(.secondary)
            
            Text(deger)
                .font(.headline.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.tertiarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

struct DetailMetrik: View {
    let baslik: LocalizedStringKey
    let deger: String
    let ikon: String
    let renk: Color
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: ikon)
                .font(.callout)
                .foregroundColor(renk)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(baslik)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                
                Text(deger)
                    .font(.caption.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity)
        .background(Color(.quaternarySystemFill))
        .cornerRadius(8)
    }
}

// Array güvenli erişim extension'ı
extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Kategori Analizi View
struct KategoriAnaliziView: View {
    let rapor: KartDetayRaporu
    @EnvironmentObject var appSettings: AppSettings
    @State private var secilenKategori: KategoriHarcamasi?
    @State private var tumKategorileriGoster = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("reports.creditcard.category_analysis")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            // Donut Chart - Tam genişlik
            VStack(spacing: 16) {
                DonutChartView(data: rapor.kategoriDagilimi)
                    .environmentObject(appSettings) // <-- BU SATIRI EKLEYİN
                    .frame(height: 220)
                
                // Kategori listesi - Grid yapısında
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ], spacing: 12) {
                    ForEach(tumKategorileriGoster ? rapor.kategoriDagilimi : Array(rapor.kategoriDagilimi.prefix(4))) { kategori in
                        KategoriKartView(
                            kategori: kategori,
                            toplamTutar: rapor.toplamHarcama,
                            isSelected: secilenKategori?.id == kategori.id,
                            onTap: {
                                withAnimation(.spring(response: 0.3)) {
                                    secilenKategori = kategori
                                }
                            }
                        )
                    }
                }
                
                // Daha fazla/Az göster butonu
                if rapor.kategoriDagilimi.count > 4 {
                    Button(action: {
                        withAnimation(.spring(response: 0.3)) {
                            tumKategorileriGoster.toggle()
                        }
                    }) {
                        HStack {
                            // Bundle extension'ınızı kullanarak
                            let bundle = Bundle.getLanguageBundle(for: appSettings.languageCode)
                            
                            if tumKategorileriGoster {
                                Text(bundle.localizedString(forKey: "reports.creditcard.show_less", value: nil, table: nil))
                            } else {
                                let format = bundle.localizedString(forKey: "reports.creditcard.more_categories", value: nil, table: nil)
                                Text(String(format: format, rapor.kategoriDagilimi.count - 4))
                            }
                            
                            Image(systemName: tumKategorileriGoster ? "chevron.up" : "chevron.down")
                                .font(.caption)
                        }
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.accentColor)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .onAppear {
            secilenKategori = rapor.kategoriDagilimi.first
        }
    }
}

struct KategoriKartView: View {
    let kategori: KategoriHarcamasi
    let toplamTutar: Double
    let isSelected: Bool
    let onTap: () -> Void
    @EnvironmentObject var appSettings: AppSettings
    
    private var yuzde: Double {
        toplamTutar > 0 ? (kategori.tutar / toplamTutar) * 100 : 0
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: kategori.ikonAdi)
                        .font(.title3)
                        .foregroundColor(kategori.renk)
                        .frame(width: 28, height: 28)
                        .background(kategori.renk.opacity(0.15))
                        .cornerRadius(6)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(LocalizedStringKey(kategori.localizationKey ?? kategori.kategori))
                            .font(.caption)
                            .fontWeight(isSelected ? .semibold : .regular)
                            .lineLimit(1)
                            .foregroundColor(.primary)
                        
                        Text(String(format: "%.1f%%", yuzde))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(formatCurrency(
                        amount: kategori.tutar,
                        currencyCode: appSettings.currencyCode,
                        localeIdentifier: appSettings.languageCode
                    ))
                    .font(.subheadline.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    
                    // Yüzde çubuğu
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.gray.opacity(0.1))
                                .frame(height: 4)
                            
                            RoundedRectangle(cornerRadius: 2)
                                .fill(kategori.renk)
                                .frame(width: (yuzde / 100) * geometry.size.width, height: 4)
                        }
                    }
                    .frame(height: 4)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? kategori.renk.opacity(0.1) : Color(.tertiarySystemGroupedBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isSelected ? kategori.renk : Color.clear, lineWidth: 2)
                    )
            )
            .scaleEffect(isSelected ? 0.98 : 1.0)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Gelişmiş Harcama Trendi View
struct GelismisHarcamaTrendiView: View {
    let rapor: KartDetayRaporu
    @EnvironmentObject var appSettings: AppSettings
    @State private var grafikTipi: GrafikTipi = .gunluk
    @State private var secilenTarih: Date?
    
    enum GrafikTipi: String, CaseIterable {
        case gunluk = "reports.creditcard.daily"
        case haftalik = "reports.creditcard.weekly"
        // kategori case'i kaldırıldı
    }
    
    private var haftalikVeriler: [HaftalikHarcama] {
        let calendar = Calendar.current
        let haftalikGruplar = Dictionary(grouping: rapor.gunlukHarcamaTrendi) { harcama in
            calendar.dateInterval(of: .weekOfYear, for: harcama.gun)?.start ?? harcama.gun
        }
        
        return haftalikGruplar.map { (hafta, gunler) in
            HaftalikHarcama(
                haftaBasi: hafta,
                toplamTutar: gunler.reduce(0) { $0 + $1.tutar },
                gunSayisi: gunler.count
            )
        }.sorted { $0.haftaBasi < $1.haftaBasi }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Başlık ve grafik tipi seçici
            HStack {
                Text("reports.creditcard.spending_trend")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Picker("", selection: $grafikTipi) {
                    ForEach(GrafikTipi.allCases, id: \.self) { tip in
                        Text(LocalizedStringKey(tip.rawValue)).tag(tip)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 150) // Genişlik azaltıldı
            }
            
            // Seçilen tarih detayı
            if let tarih = secilenTarih,
               let veri = rapor.gunlukHarcamaTrendi.first(where: { Calendar.current.isDate($0.gun, inSameDayAs: tarih) }) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(tarih, style: .date)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Text(formatCurrency(
                            amount: veri.tutar,
                            currencyCode: appSettings.currencyCode,
                            localeIdentifier: appSettings.languageCode
                        ))
                        .font(.headline.bold())
                    }
                    
                    Spacer()
                    
                    if let islemSayisi = veri.islemSayisi {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("reports.creditcard.transactions")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            
                            Text("\(islemSayisi)")
                                .font(.caption.bold())
                        }
                    }
                }
                .padding()
                .background(Color(.tertiarySystemGroupedBackground))
                .cornerRadius(12)
                .transition(.asymmetric(
                    insertion: .scale.combined(with: .opacity),
                    removal: .scale.combined(with: .opacity)
                ))
            }
            
            // Grafik
            switch grafikTipi {
            case .gunluk:
                gunlukGrafik
            case .haftalik:
                haftalikGrafik
            // kategori case kaldırıldı
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
    
    @ViewBuilder
    private var gunlukGrafik: some View {
        Chart(rapor.gunlukHarcamaTrendi) { harcama in
            BarMark(
                x: .value("Gün", harcama.gun, unit: .day),
                y: .value("Tutar", harcama.tutar)
            )
            .foregroundStyle(rapor.hesap.renk.gradient)
            .cornerRadius(4)
            
            if Calendar.current.isDate(harcama.gun, inSameDayAs: secilenTarih ?? Date.distantPast) {
                RuleMark(x: .value("Seçilen", harcama.gun))
                    .foregroundStyle(Color.gray.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [4, 4]))
            }
        }
        .frame(height: 200)
        .chartXSelection(value: $secilenTarih)
    }
    
    @ViewBuilder
    private var haftalikGrafik: some View {
        Chart(haftalikVeriler) { hafta in
            BarMark(
                x: .value("Hafta", hafta.haftaBasi, unit: .weekOfYear),
                y: .value("Ortalama", hafta.ortalamaGunluk)
            )
            .foregroundStyle(rapor.hesap.renk.gradient)
            .cornerRadius(4)
            .annotation(position: .top) {
                Text(formatCompactCurrency(amount: hafta.toplamTutar))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(height: 200)
    }
    
    // kategoriZamanliGrafik fonksiyonu kaldırıldı
    
    private func formatCompactCurrency(amount: Double) -> String {
        if amount >= 1000 {
            return String(format: "%.1fK", amount / 1000)
        }
        return String(format: "%.0f", amount)
    }
}

// MARK: - Taksitli İşlemler Özeti View
struct TaksitliIslemlerOzetiView: View {
    let taksitliIslemler: [TaksitliIslemOzeti]
    @EnvironmentObject var appSettings: AppSettings
    @State private var expandedItems: Set<UUID> = []
    
    var toplamAylikTaksit: Double {
        taksitliIslemler.reduce(0) { $0 + $1.aylikTaksitTutari }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Başlık ve toplam
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("reports.creditcard.installments")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    
                    Text(String(format: NSLocalizedString("reports.creditcard.installment_count", comment: ""), taksitliIslemler.count))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("reports.creditcard.monthly_total")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    
                    Text(formatCurrency(
                        amount: toplamAylikTaksit,
                        currencyCode: appSettings.currencyCode,
                        localeIdentifier: appSettings.languageCode
                    ))
                    .font(.headline.bold())
                    .foregroundColor(.orange)
                }
            }
            
            // Taksitli işlem listesi
            VStack(spacing: 8) {
                ForEach(taksitliIslemler) { taksit in
                    TaksitliIslemKartiView(
                        taksit: taksit,
                        isExpanded: expandedItems.contains(taksit.id),
                        onToggle: {
                            withAnimation(.spring(response: 0.3)) {
                                if expandedItems.contains(taksit.id) {
                                    expandedItems.remove(taksit.id)
                                } else {
                                    expandedItems.insert(taksit.id)
                                }
                            }
                        }
                    )
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
}

struct TaksitliIslemKartiView: View {
    let taksit: TaksitliIslemOzeti
    let isExpanded: Bool
    let onToggle: () -> Void
    @EnvironmentObject var appSettings: AppSettings
    
    private var tamamlanmaYuzdesi: Double {
        Double(taksit.odenenTaksitSayisi) / Double(taksit.toplamTaksitSayisi) * 100
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Button(action: onToggle) {
                HStack {
                    // İkon ve isim
                    HStack(spacing: 12) {
                        Image(systemName: "creditcard.viewfinder")
                            .font(.title3)
                            .foregroundColor(.orange)
                            .frame(width: 36, height: 36)
                            .background(Color.orange.opacity(0.15))
                            .cornerRadius(8)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(taksit.isim)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .lineLimit(1)
                            
                            HStack(spacing: 4) {
                                // Mevcut çeviri anahtarını kullanarak "Taksit:" metnini al
                                Text(LocalizedStringKey("loan_report.installment_no"))
                                
                                // Sayıları yanına ekle
                                Text("\(taksit.odenenTaksitSayisi)/\(taksit.toplamTaksitSayisi)")
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    // Aylık tutar
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(formatCurrency(
                            amount: taksit.aylikTaksitTutari,
                            currencyCode: appSettings.currencyCode,
                            localeIdentifier: appSettings.languageCode
                        ))
                        .font(.subheadline.bold())
                        
                        Text("reports.creditcard.monthly")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 20)
                }
                .padding()
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                VStack(spacing: 12) {
                    Divider()
                    
                    // İlerleme çubuğu
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("reports.creditcard.progress")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            Spacer()
                            
                            Text(String(format: "%.0f%%", tamamlanmaYuzdesi))
                                .font(.caption.bold())
                        }
                        
                        ProgressView(value: tamamlanmaYuzdesi, total: 100)
                            .tint(.orange)
                    }
                    
                    // Detaylar
                    HStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("reports.creditcard.total_amount")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            
                            Text(formatCurrency(
                                amount: taksit.toplamTutar,
                                currencyCode: appSettings.currencyCode,
                                localeIdentifier: appSettings.languageCode
                            ))
                            .font(.caption.bold())
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("reports.creditcard.remaining")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            
                            Text(formatCurrency(
                                amount: taksit.kalanTutar,
                                currencyCode: appSettings.currencyCode,
                                localeIdentifier: appSettings.languageCode
                            ))
                            .font(.caption.bold())
                            .foregroundColor(.orange)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))
            }
        }
        .background(Color(.tertiarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

// MARK: - Kartlar Arası Karşılaştırma View
struct KartlarArasiKarsilastirmaView: View {
    let raporlar: [KartDetayRaporu]
    @EnvironmentObject var appSettings: AppSettings
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("reports.creditcard.card_comparison")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            // Karşılaştırma grafiği
            Chart(raporlar) { rapor in
                BarMark(
                    x: .value("Kart", rapor.hesap.isim),
                    y: .value("Harcama", rapor.toplamHarcama)
                )
                .foregroundStyle(rapor.hesap.renk.gradient)
                .cornerRadius(8)
                .annotation(position: .top) {
                    VStack(spacing: 2) {
                        Text(formatCurrency(
                            amount: rapor.toplamHarcama,
                            currencyCode: appSettings.currencyCode,
                            localeIdentifier: appSettings.languageCode
                        ))
                        .font(.caption2.bold())
                        
                        if let doluluk = rapor.kartDolulukOrani {
                            Text(String(format: "%.0f%%", doluluk))
                                .font(.caption2)
                                .foregroundColor(
                                    doluluk > 80 ? .red :
                                    doluluk > 60 ? .orange : .green
                                )
                        }
                    }
                }
            }
            .frame(height: 250)
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let doubleValue = value.as(Double.self) {
                            Text(formatCompactCurrency(amount: doubleValue))
                                .font(.caption2)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
    
    private func formatCompactCurrency(amount: Double) -> String {
        if amount >= 1_000_000 {
            return String(format: "%.1fM", amount / 1_000_000)
        } else if amount >= 1_000 {
            return String(format: "%.1fK", amount / 1_000)
        }
        return String(format: "%.0f", amount)
    }
}

// MARK: - Karşılaştırma Tablosu View
struct KarsilastirmaTablosuView: View {
    let raporlar: [KartDetayRaporu]
    @EnvironmentObject var appSettings: AppSettings
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("reports.creditcard.detailed_comparison")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            // Tablo başlıkları
            HStack {
                Text("reports.creditcard.card")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text("reports.creditcard.spending")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .frame(width: 80, alignment: .trailing)
                
                Text("reports.creditcard.transactions")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .frame(width: 60, alignment: .center)
                
                Text("reports.creditcard.usage")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .frame(width: 60, alignment: .trailing)
            }
            .padding(.horizontal)
            
            Divider()
            
            // Kart satırları
            VStack(spacing: 8) {
                ForEach(raporlar) { rapor in
                    karsilastirmaSatiri(rapor: rapor)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
    
    @ViewBuilder
    private func karsilastirmaSatiri(rapor: KartDetayRaporu) -> some View {
        HStack {
            // Kart adı ve ikonu
            HStack(spacing: 8) {
                Image(systemName: rapor.hesap.ikonAdi)
                    .font(.callout)
                    .foregroundColor(rapor.hesap.renk)
                
                Text(rapor.hesap.isim)
                    .font(.caption)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Harcama
            Text(formatCurrency(
                amount: rapor.toplamHarcama,
                currencyCode: appSettings.currencyCode,
                localeIdentifier: appSettings.languageCode
            ))
            .font(.caption.bold())
            .frame(width: 80, alignment: .trailing)
            
            // İşlem sayısı
            Text("\(rapor.islemSayisi ?? 0)")
                .font(.caption)
                .frame(width: 60, alignment: .center)
            
            // Kullanım oranı
            if let doluluk = rapor.kartDolulukOrani {
                Text(String(format: "%.0f%%", doluluk))
                    .font(.caption.bold())
                    .foregroundColor(
                        doluluk > 80 ? .red :
                        doluluk > 60 ? .orange : .green
                    )
                    .frame(width: 60, alignment: .trailing)
            } else {
                Text("-")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 60, alignment: .trailing)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.tertiarySystemGroupedBackground))
        .cornerRadius(8)
    }
}

// MARK: - Özet Görünüm View'ları
struct ToplamHarcamaDagilimiView: View {
    let raporlar: [KartDetayRaporu]
    @EnvironmentObject var appSettings: AppSettings
    
    private var toplamHarcama: Double {
        raporlar.reduce(0) { $0 + $1.toplamHarcama }
    }
    
    private var kartDagilimVerisi: [KategoriHarcamasi] {
        raporlar.map { rapor in
            KategoriHarcamasi(
                kategori: rapor.hesap.isim,
                tutar: rapor.toplamHarcama,
                renk: rapor.hesap.renk,
                localizationKey: nil,
                ikonAdi: rapor.hesap.ikonAdi
            )
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("reports.creditcard.total_distribution")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Text(formatCurrency(
                    amount: toplamHarcama,
                    currencyCode: appSettings.currencyCode,
                    localeIdentifier: appSettings.languageCode
                ))
                .font(.headline.bold())
            }
            
            // Pasta grafiği
            DonutChartView(data: kartDagilimVerisi)
                .frame(height: 220)
            
            // Kart detayları
            VStack(spacing: 8) {
                ForEach(raporlar) { rapor in
                    HStack {
                        Image(systemName: rapor.hesap.ikonAdi)
                            .font(.callout)
                            .foregroundColor(rapor.hesap.renk)
                            .frame(width: 24)
                        
                        Text(rapor.hesap.isim)
                            .font(.caption)
                        
                        Spacer()
                        
                        Text(String(format: "%.1f%%", (rapor.toplamHarcama / toplamHarcama) * 100))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Text(formatCurrency(
                            amount: rapor.toplamHarcama,
                            currencyCode: appSettings.currencyCode,
                            localeIdentifier: appSettings.languageCode
                        ))
                        .font(.caption.bold())
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
}

struct ToplamKategoriAnaliziView: View {
    let raporlar: [KartDetayRaporu]
    @EnvironmentObject var appSettings: AppSettings
    
    private var tumKategoriler: [KategoriHarcamasi] {
        var kategoriToplam: [String: (tutar: Double, renk: Color, ikon: String, localizationKey: String?)] = [:]
        
        for rapor in raporlar {
            for kategori in rapor.kategoriDagilimi {
                let key = kategori.kategori
                if let mevcut = kategoriToplam[key] {
                    kategoriToplam[key] = (
                        tutar: mevcut.tutar + kategori.tutar,
                        renk: kategori.renk,
                        ikon: kategori.ikonAdi,
                        localizationKey: kategori.localizationKey
                    )
                } else {
                    kategoriToplam[key] = (
                        tutar: kategori.tutar,
                        renk: kategori.renk,
                        ikon: kategori.ikonAdi,
                        localizationKey: kategori.localizationKey
                    )
                }
            }
        }
        
        return kategoriToplam.map { (kategori, veri) in
            KategoriHarcamasi(
                kategori: kategori,
                tutar: veri.tutar,
                renk: veri.renk,
                localizationKey: veri.localizationKey,
                ikonAdi: veri.ikon
            )
        }.sorted { $0.tutar > $1.tutar }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("reports.creditcard.category_summary")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            if tumKategoriler.isEmpty {
                Text("reports.creditcard.no_categories")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
            } else {
                VStack(spacing: 8) {
                    ForEach(tumKategoriler.prefix(10)) { kategori in
                        HStack {
                            Image(systemName: kategori.ikonAdi)
                                .font(.callout)
                                .foregroundColor(kategori.renk)
                                .frame(width: 32, height: 32)
                                .background(kategori.renk.opacity(0.15))
                                .cornerRadius(6)
                            
                            Text(LocalizedStringKey(kategori.localizationKey ?? kategori.kategori))
                                .font(.caption)
                            
                            Spacer()
                            
                            Text(formatCurrency(
                                amount: kategori.tutar,
                                currencyCode: appSettings.currencyCode,
                                localeIdentifier: appSettings.languageCode
                            ))
                            .font(.caption.bold())
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 8)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
}

struct GunlukOrtalamaAnaliziView: View {
    let raporlar: [KartDetayRaporu]
    @EnvironmentObject var appSettings: AppSettings
    
    private var gunlukOrtalamalar: [(kart: String, ortalama: Double, renk: Color)] {
        raporlar.map { rapor in
            let gunSayisi = rapor.gunlukHarcamaTrendi.count
            let ortalama = gunSayisi > 0 ? rapor.toplamHarcama / Double(gunSayisi) : 0
            return (rapor.hesap.isim, ortalama, rapor.hesap.renk)
        }.sorted { $0.ortalama > $1.ortalama }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("reports.creditcard.daily_averages")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Chart(gunlukOrtalamalar, id: \.kart) { veri in
                BarMark(
                    x: .value("Ortalama", veri.ortalama),
                    y: .value("Kart", veri.kart)
                )
                .foregroundStyle(veri.renk.gradient)
                .cornerRadius(6)
                .annotation(position: .trailing) {
                    Text(formatCurrency(
                        amount: veri.ortalama,
                        currencyCode: appSettings.currencyCode,
                        localeIdentifier: appSettings.languageCode
                    ))
                    .font(.caption2.bold())
                    .padding(.leading, 4)
                }
            }
            .frame(height: CGFloat(raporlar.count * 50))
            .chartXAxis(.hidden)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
}

// MARK: - Yardımcı Modeller
struct HaftalikHarcama: Identifiable {
    let id = UUID()
    let haftaBasi: Date
    let toplamTutar: Double
    let gunSayisi: Int
    
    var ortalamaGunluk: Double {
        gunSayisi > 0 ? toplamTutar / Double(gunSayisi) : 0
    }
}
// Kompakt kart görünümü
struct KompaktKartView: View {
    let rapor: KartDetayRaporu
    @EnvironmentObject var appSettings: AppSettings
    
    var body: some View {
        VStack(spacing: 8) {
            // Kart başlığı ve limit göstergesi
            HStack(spacing: 8) {
                Image(systemName: rapor.hesap.ikonAdi)
                    .font(.headline)
                    .foregroundColor(rapor.hesap.renk)
                    .frame(width: 30, height: 30)
                    .background(rapor.hesap.renk.opacity(0.15))
                    .cornerRadius(8)
                
                Text(rapor.hesap.isim)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Spacer()
            }
            
            // Harcama bilgisi
            VStack(alignment: .leading, spacing: 4) {
                Text(formatCurrency(
                    amount: rapor.toplamHarcama,
                    currencyCode: appSettings.currencyCode,
                    localeIdentifier: appSettings.languageCode
                ))
                .font(.headline.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                
                if let limit = rapor.kartLimiti {
                    Text("Limit: " + formatCurrency(
                        amount: limit,
                        currencyCode: appSettings.currencyCode,
                        localeIdentifier: appSettings.languageCode
                    ))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                }
            }
            
            // Kullanım oranı
            if let dolulukOrani = rapor.kartDolulukOrani {
                VStack(spacing: 4) {
                    ProgressView(value: dolulukOrani, total: 100)
                        .tint(
                            dolulukOrani > 80 ? .red :
                            dolulukOrani > 60 ? .orange : .green
                        )
                        .scaleEffect(x: 1, y: 0.8, anchor: .center)
                    
                    HStack {
                        Text(String(format: "%.0f%%", dolulukOrani))
                            .font(.caption.bold())
                            .foregroundColor(
                                dolulukOrani > 80 ? .red :
                                dolulukOrani > 60 ? .orange : .green
                            )
                        
                        Spacer()
                        
                        Text("reports.creditcard.usage")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .frame(width: 160)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }
}
// KategoriLegendiView tanımı
struct KategoriLegendiView: View {
    let kategoriler: [KategoriHarcamasi]
    let toplamTutar: Double
    @EnvironmentObject var appSettings: AppSettings

    var body: some View {
        VStack(spacing: 14) {
            ForEach(kategoriler) { kategori in
                HStack(spacing: 12) {
                    Image(systemName: kategori.ikonAdi)
                        .font(.callout)
                        .foregroundColor(kategori.renk)
                        .frame(width: 38, height: 38)
                        .background(kategori.renk.opacity(0.15))
                        .cornerRadius(8)
                    
                    Text(LocalizedStringKey(kategori.localizationKey ?? kategori.kategori))
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(formatCurrency(
                            amount: kategori.tutar,
                            currencyCode: appSettings.currencyCode,
                            localeIdentifier: appSettings.languageCode
                        ))
                        .font(.callout.bold())
                        
                        if toplamTutar > 0 {
                            Text(String(format: "%.1f%%", (kategori.tutar / toplamTutar) * 100))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding(.top, 15)
    }
}
