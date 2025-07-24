// Features/ReportsDetailed/Views/KrediRaporuView.swift

import SwiftUI
import SwiftData
import Charts

struct KrediRaporuView: View {
    @State private var viewModel: KrediRaporuViewModel
    @EnvironmentObject var appSettings: AppSettings
    @State private var secilenGorunum: KrediRaporGorunum = .ozet
    @State private var genisletilmisKrediler: Set<UUID> = []
    @State private var filtre = KrediFiltre()
    @State private var secilenAy: Date = Date()
    
    let baslangicTarihi: Date
    let bitisTarihi: Date
    
    init(modelContext: ModelContext, baslangicTarihi: Date, bitisTarihi: Date) {
        self.baslangicTarihi = baslangicTarihi
        self.bitisTarihi = bitisTarihi
        _viewModel = State(initialValue: KrediRaporuViewModel(
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
                } else if viewModel.krediDetayRaporlari.isEmpty {
                    ContentUnavailableView(
                        LocalizedStringKey("loan_report.no_data"),
                        systemImage: "banknote.fill",
                        description: Text(LocalizedStringKey("loan_report.no_data_desc"))
                    )
                    .padding(.top, 100)
                } else {
                    // Görünüm seçici
                    gorunumSecici
                        .padding(.horizontal)
                    
                    // İçerik
                    switch secilenGorunum {
                    case .ozet:
                        ozetGorunumu
                    case .detay:
                        detayGorunumu
                    case .takvim:
                        takvimGorunumu
                    case .performans:
                        performansGorunumu
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
    
    // MARK: - Görünüm Seçici
    private var gorunumSecici: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(KrediRaporGorunum.allCases, id: \.self) { gorunum in
                    Button(action: {
                        withAnimation(.spring(response: 0.3)) {
                            secilenGorunum = gorunum
                        }
                    }) {
                        VStack(spacing: 8) {
                            Image(systemName: gorunum.icon)
                                .font(.title2)
                            Text(LocalizedStringKey(gorunum.rawValue))
                                .font(.caption)
                        }
                        .foregroundColor(secilenGorunum == gorunum ? .white : .primary)
                        .frame(width: 80, height: 80)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(secilenGorunum == gorunum ? Color.accentColor : Color(.tertiarySystemGroupedBackground))
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - Özet Görünümü
    @ViewBuilder
    private var ozetGorunumu: some View {
        VStack(spacing: 20) {
            // Gelişmiş özet kartı
            GelismisKrediOzetKarti(ozet: viewModel.genelOzet)
                .padding(.horizontal)
            
            // Aylık taksit yükü grafiği
            AylikTaksitYukuGrafigi(aylikVeriler: viewModel.aylikTaksitVerileri)
                .padding(.horizontal)
            
            // Kredi dağılımı
            KrediDagilimiKarti(krediler: viewModel.krediDetayRaporlari)
                .padding(.horizontal)
        }
    }
    
    // MARK: - Detay Görünümü
    @ViewBuilder
    private var detayGorunumu: some View {
        VStack(spacing: 20) {
            // Filtreleme
            FiltrelemeBolumu(filtre: $filtre)
                .padding(.horizontal)
            
            // Kredi kartları
            ForEach(viewModel.filtreliKrediler(filtre: filtre)) { rapor in
                GelismisKrediDetayKarti(
                    rapor: rapor,
                    isExpanded: genisletilmisKrediler.contains(rapor.id),
                    giderOlarakEklenenler: viewModel.giderOlarakEklenenTaksitIDleri,
                    onToggle: {
                        withAnimation(.spring(response: 0.3)) {
                            if genisletilmisKrediler.contains(rapor.id) {
                                genisletilmisKrediler.remove(rapor.id)
                            } else {
                                genisletilmisKrediler.insert(rapor.id)
                            }
                        }
                    }
                )
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Takvim Görünümü
    @ViewBuilder
    private var takvimGorunumu: some View {
        VStack(spacing: 20) {
            // Ay seçici
            AySecici(secilenAy: $secilenAy)
                .padding(.horizontal)
            
            // Ödeme takvimi
            OdemeTakvimiView(
                takvimVerileri: viewModel.odemeTakvimi(for: secilenAy),
                secilenAy: secilenAy
            )
            .padding(.horizontal)
        }
    }
    
    // MARK: - Performans Görünümü
    @ViewBuilder
    private var performansGorunumu: some View {
        VStack(spacing: 20) {
            // Genel performans kartı
            GenelPerformansKarti(
                toplamPerformans: viewModel.genelPerformansSkoru,
                istatistikler: viewModel.krediIstatistikleri
            )
            .padding(.horizontal)
            
            // Kredi bazlı performans
            ForEach(viewModel.krediDetayRaporlari) { rapor in
                KrediPerformansKarti(rapor: rapor)
                    .padding(.horizontal)
            }
        }
    }
}

// MARK: - Alt Bileşenler

struct GelismisKrediOzetKarti: View {
    let ozet: KrediGenelOzet
    @EnvironmentObject var appSettings: AppSettings
    
    var body: some View {
        VStack(spacing: 20) {
            // Başlık
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("loan_report.overview")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(formatCurrency(
                        amount: ozet.toplamKalanBorc,
                        currencyCode: appSettings.currencyCode,
                        localeIdentifier: appSettings.languageCode
                    ))
                    .font(.title.bold())
                }
                
                Spacer()
                
                // İlerleme
                VStack(alignment: .trailing, spacing: 4) {
                    Text(String(format: "%.1f%%", ozet.ilerlemeYuzdesi))
                        .font(.headline.bold())
                        .foregroundColor(.green)
                    Text("loan_report.completed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            // İlerleme çubuğu
            ProgressView(value: ozet.ilerlemeYuzdesi, total: 100)
                .tint(.green)
                .scaleEffect(x: 1, y: 2, anchor: .center)
            
            // Detay metrikler
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                MetrikKutu(
                    baslik: "loan_report.active_loans",
                    deger: "\(ozet.aktifKrediSayisi)",
                    ikon: "creditcard.viewfinder",
                    renk: .blue
                )
                
                MetrikKutu(
                    baslik: "loan_report.monthly_payment",
                    deger: formatCurrency(
                        amount: ozet.aylikToplamTaksitYuku,
                        currencyCode: appSettings.currencyCode,
                        localeIdentifier: appSettings.languageCode
                    ),
                    ikon: "calendar.badge.clock",
                    renk: .orange
                )
                
                MetrikKutu(
                    baslik: "loan_report.total_paid",
                    deger: formatCurrency(
                        amount: ozet.toplamOdenenTutar,
                        currencyCode: appSettings.currencyCode,
                        localeIdentifier: appSettings.languageCode
                    ),
                    ikon: "checkmark.circle.fill",
                    renk: .green
                )
                
                MetrikKutu(
                    baslik: "loan_report.remaining",
                    deger: formatCurrency(
                        amount: ozet.toplamKalanBorc,
                        currencyCode: appSettings.currencyCode,
                        localeIdentifier: appSettings.languageCode
                    ),
                    ikon: "hourglass",
                    renk: .red
                )
            }
            
            // Tahmini bitiş
            if let tahminiTarih = ozet.tahminiTamamlanmaTarihi {
                HStack {
                    Image(systemName: "calendar.badge.checkmark")
                        .foregroundColor(.green)
                    Text("loan_report.estimated_completion")
                        .font(.caption)
                    Spacer()
                    Text(tahminiTarih, style: .date)
                        .font(.caption.bold())
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(12)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
}

struct GelismisKrediDetayKarti: View {
    let rapor: KrediDetayRaporu
    let isExpanded: Bool
    let giderOlarakEklenenler: Set<UUID>
    let onToggle: () -> Void
    @EnvironmentObject var appSettings: AppSettings
    
    var body: some View {
        VStack(spacing: 0) {
            // Başlık
            Button(action: onToggle) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(rapor.hesap.isim)
                            .font(.headline)
                        
                        if let detay = rapor.krediDetaylari {
                            HStack(spacing: 12) {
                                // Faiz bilgisi
                                Label(
                                    String(format: "%.2f%%", detay.faizOrani),
                                    systemImage: "percent"
                                )
                                .font(.caption)
                                .foregroundColor(.secondary)
                                
                                // Taksit durumu
                                Label(
                                    "\(detay.odenenTaksitSayisi)/\(detay.toplamTaksitSayisi)",
                                    systemImage: "number.square"
                                )
                                .font(.caption)
                                .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(formatCurrency(
                            amount: rapor.krediDetaylari?.kalanAnaparaTutari ?? 0,
                            currencyCode: appSettings.currencyCode,
                            localeIdentifier: appSettings.languageCode
                        ))
                        .font(.headline.bold())
                        
                        // İlerleme
                        HStack(spacing: 4) {
                            Text(String(format: "%.0f%%", rapor.ilerlemeYuzdesi))
                                .font(.caption)
                                .foregroundColor(.green)
                            
                            Circle()
                                .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                                .overlay(
                                    Circle()
                                        .trim(from: 0, to: rapor.ilerlemeYuzdesi / 100)
                                        .stroke(Color.green, lineWidth: 2)
                                        .rotationEffect(.degrees(-90))
                                )
                                .frame(width: 20, height: 20)
                        }
                    }
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            
            if isExpanded {
                VStack(spacing: 16) {
                    Divider()
                    
                    // Kredi detayları
                    if let detay = rapor.krediDetaylari {
                        KrediDetayBilgileri(detay: detay)
                    }
                    
                    // Performans
                    PerformansMiniKart(performans: rapor.odemePerformansi)
                    
                    // Sonraki taksit
                    if let sonraki = rapor.sonrakiTaksit {
                        SonrakiTaksitKarti(taksit: sonraki)
                    }
                    
                    // Taksit listesi
                    TaksitListesiKompakt(
                        rapor: rapor,
                        giderOlarakEklenenler: giderOlarakEklenenler
                    )
                }
                .padding()
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .scale.combined(with: .opacity)
                ))
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
}

struct MetrikKutu: View {
    let baslik: LocalizedStringKey
    let deger: String
    let ikon: String
    let renk: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: ikon)
                .font(.title2)
                .foregroundColor(renk)
            
            Text(deger)
                .font(.headline.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            
            Text(baslik)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.tertiarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

// KrediRaporuView.swift dosyasının devamı...

// MARK: - Eksik Bileşenler

struct AylikTaksitYukuGrafigi: View {
    let aylikVeriler: [(ay: Date, tutar: Double)]
    @EnvironmentObject var appSettings: AppSettings
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("loan_report.monthly_payment_load")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            if aylikVeriler.isEmpty {
                Text("loan_report.no_future_payments")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 150, alignment: .center)
            } else {
                Chart(aylikVeriler, id: \.ay) { veri in
                    BarMark(
                        x: .value("Month", veri.ay, unit: .month),
                        y: .value("Amount", veri.tutar)
                    )
                    .foregroundStyle(Color.blue.gradient)
                    .cornerRadius(8)
                    
                    RuleMark(
                        y: .value("Average", aylikVeriler.map(\.tutar).reduce(0, +) / Double(aylikVeriler.count))
                    )
                    .foregroundStyle(.gray.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 3]))
                }
                .frame(height: 200)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .month)) { value in
                        AxisValueLabel {
                            if let dateValue = value.as(Date.self) {
                                Text(monthAbbreviation(from: dateValue))
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let doubleValue = value.as(Double.self) {
                                Text(formatCurrency(
                                    amount: doubleValue,
                                    currencyCode: appSettings.currencyCode,
                                    localeIdentifier: appSettings.languageCode
                                ))
                                .font(.caption2)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
    
    private func monthAbbreviation(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: appSettings.languageCode)
        formatter.dateFormat = "MMM"
        return formatter.string(from: date)
    }
}

struct KrediDagilimiKarti: View {
    let krediler: [KrediDetayRaporu]
    @EnvironmentObject var appSettings: AppSettings
    
    private var dagılımVerisi: [KategoriHarcamasi] {
        krediler.compactMap { rapor in
            guard let detay = rapor.krediDetaylari else { return nil }
            return KategoriHarcamasi(
                kategori: rapor.hesap.isim,
                tutar: detay.kalanAnaparaTutari,
                renk: rapor.hesap.renk, // Bu satır zaten mevcut
                localizationKey: nil,
                ikonAdi: rapor.hesap.ikonAdi
            )
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("loan_report.distribution")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            if dagılımVerisi.isEmpty {
                Text("loan_report.no_active_loans")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 200, alignment: .center)
            } else {
                HStack(alignment: .top, spacing: 20) {
                    // Donut Chart
                    DonutChartView(data: dagılımVerisi)
                        .frame(height: 180)
                        .frame(maxWidth: .infinity)
                    
                    // Detaylar
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(dagılımVerisi.prefix(5)) { veri in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(veri.renk)
                                    .frame(width: 12, height: 12)
                                
                                Text(veri.kategori)
                                    .font(.caption)
                                    .lineLimit(1)
                                
                                Spacer()
                                
                                Text(formatCurrency(
                                    amount: veri.tutar,
                                    currencyCode: appSettings.currencyCode,
                                    localeIdentifier: appSettings.languageCode
                                ))
                                .font(.caption.bold())
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
}

struct FiltrelemeBolumu: View {
    @Binding var filtre: KrediFiltre
    
    var body: some View {
        VStack(spacing: 12) {
            // Arama
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                
                TextField(LocalizedStringKey("loan_report.search_placeholder"), text: $filtre.aramaMetni)
                    .textFieldStyle(.plain)
                
                if !filtre.aramaMetni.isEmpty {
                    Button(action: { filtre.aramaMetni = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(10)
            .background(Color(.tertiarySystemGroupedBackground))
            .cornerRadius(10)
            
            HStack {
                // Aktif filtresi
                Toggle(isOn: $filtre.sadecekAktifler) {
                    Label("loan_report.active_only", systemImage: "checkmark.circle")
                        .font(.caption)
                }
                .toggleStyle(.button)
                .buttonStyle(.bordered)
                
                Spacer()
                
                // Sıralama
                Menu {
                    ForEach(KrediSiralama.allCases, id: \.self) { siralama in
                        Button(action: { filtre.siralama = siralama }) {
                            Label(
                                LocalizedStringKey(siralama.rawValue),
                                systemImage: filtre.siralama == siralama ? "checkmark" : ""
                            )
                        }
                    }
                } label: {
                    Label("loan_report.sort", systemImage: "arrow.up.arrow.down")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
}

struct AySecici: View {
    @Binding var secilenAy: Date
    @EnvironmentObject var appSettings: AppSettings
    
    var body: some View {
        HStack {
            Button(action: {
                withAnimation {
                    secilenAy = Calendar.current.date(byAdding: .month, value: -1, to: secilenAy) ?? secilenAy
                }
            }) {
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .foregroundColor(.accentColor)
            }
            
            Spacer()
            
            Text(localizedMonthYear(from: secilenAy))
                .font(.headline)
            
            Spacer()
            
            Button(action: {
                withAnimation {
                    secilenAy = Calendar.current.date(byAdding: .month, value: 1, to: secilenAy) ?? secilenAy
                }
            }) {
                Image(systemName: "chevron.right")
                    .font(.title3)
                    .foregroundColor(.accentColor)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
    private func localizedMonthYear(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: appSettings.languageCode)
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
}

struct OdemeTakvimiView: View {
    let takvimVerileri: [OdemeTakvimi]
    let secilenAy: Date
    @EnvironmentObject var appSettings: AppSettings
    @State private var secilenGun: Date?
    @State private var secilenGunTaksitleri: [OdemeTakvimi.TaksitOzeti] = []
    @State private var taksitDetayGoster = false
    
    private var takvimGunleri: [Date] {
        let calendar = Calendar.current
        let interval = calendar.dateInterval(of: .month, for: secilenAy)!
        let firstWeekday = calendar.component(.weekday, from: interval.start) - 1
        let dayCount = calendar.range(of: .day, in: .month, for: secilenAy)!.count
        
        var days: [Date] = []
        
        // Önceki ayın son günleri
        for i in (0..<firstWeekday).reversed() {
            if let date = calendar.date(byAdding: .day, value: -i-1, to: interval.start) {
                days.append(date)
            }
        }
        
        // Bu ayın günleri
        for i in 0..<dayCount {
            if let date = calendar.date(byAdding: .day, value: i, to: interval.start) {
                days.append(date)
            }
        }
        
        // Sonraki ayın ilk günleri
        let remainingDays = 42 - days.count
        for i in 0..<remainingDays {
            if let date = calendar.date(byAdding: .day, value: i, to: interval.end) {
                days.append(date)
            }
        }
        
        return days
    }
    
    // Aylık özet hesaplamaları
    private var aylikToplamTutar: Double {
        takvimVerileri.reduce(0) { $0 + $1.toplamTutar }
    }
    
    private var aylikOdenenTutar: Double {
        takvimVerileri.flatMap { $0.taksitler }
            .filter { $0.odendiMi }
            .reduce(0) { $0 + $1.tutar }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Hafta günleri başlıkları
            HStack {
                ForEach(0..<7) { index in
                    Text(localizedWeekdaySymbol(at: index))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            
            // Takvim günleri
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
                ForEach(takvimGunleri, id: \.self) { gun in
                    TakvimGunView(
                        gun: gun,
                        secilenAy: secilenAy,
                        taksitler: takvimVerileri.first { Calendar.current.isDate($0.ay, inSameDayAs: gun) }?.taksitler ?? [],
                        onTap: {
                            secilenGun = gun
                        }
                    )
                }
            }
            
            // Legend
            HStack(spacing: 20) {
                LegendItem(color: .green, text: "loan_report.legend.paid")
                LegendItem(color: .orange, text: "loan_report.legend.pending")
                LegendItem(color: .red, text: "loan_report.legend.overdue")
            }
            .padding(.vertical, 12)
            .padding(.horizontal)
            .background(Color(.tertiarySystemGroupedBackground))
            .cornerRadius(10)
            
            Divider()
            
            // Aylık özet
            VStack(spacing: 12) {
                Text("loan_report.this_month_summary")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                HStack {
                    Text("loan_report.total_installments")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Text(formatCurrency(
                        amount: aylikToplamTutar,
                        currencyCode: appSettings.currencyCode,
                        localeIdentifier: appSettings.languageCode
                    ))
                    .font(.subheadline.bold())
                }
                
                HStack {
                    Text("loan_report.paid_installments")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Text(formatCurrency(
                        amount: aylikOdenenTutar,
                        currencyCode: appSettings.currencyCode,
                        localeIdentifier: appSettings.languageCode
                    ))
                    .font(.subheadline.bold())
                    .foregroundColor(.green)
                }
            }
            .padding()
            .background(Color(.tertiarySystemGroupedBackground))
            .cornerRadius(12)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .sheet(item: $secilenGun) { gun in
            TaksitDetaySheet(
                gun: gun,
                takvimVerileri: takvimVerileri // taksitler yerine takvimVerileri gönderiyoruz
            )
            .environmentObject(appSettings)
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }
    
    private func localizedWeekdaySymbol(at index: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: appSettings.languageCode)
        
        // Pazartesi'den başlayan sıralama için index'i ayarla
        let adjustedIndex = (index + 1) % 7
        
        return formatter.veryShortWeekdaySymbols[adjustedIndex]
    }
}

struct LegendItem: View {
    let color: Color
    let text: LocalizedStringKey
    
    var body: some View {
        HStack(spacing: 6) {
            Rectangle()
                .fill(color)
                .frame(width: 20, height: 3)
                .cornerRadius(1.5)
            
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct TakvimGunView: View {
    let gun: Date
    let secilenAy: Date
    let taksitler: [OdemeTakvimi.TaksitOzeti]
    let onTap: () -> Void // YENİ
    @EnvironmentObject var appSettings: AppSettings
    
    private var isCurrentMonth: Bool {
        Calendar.current.isDate(gun, equalTo: secilenAy, toGranularity: .month)
    }
    
    private var isToday: Bool {
        Calendar.current.isDateInToday(gun)
    }
    
    private func taksitRengi(taksit: OdemeTakvimi.TaksitOzeti) -> Color {
        if taksit.odendiMi {
            return .green
        } else if taksit.odemeTarihi < Date() {
            return .red // Gecikmiş
        } else {
            return .orange // Henüz ödenmemiş
        }
    }
    
    private var toplamTutar: Double {
        taksitler.reduce(0) { $0 + $1.tutar }
    }
    
    var body: some View {
        VStack(spacing: 2) {
            // Gün numarası
            Text("\(Calendar.current.component(.day, from: gun))")
                .font(.caption)
                .fontWeight(isToday ? .bold : .regular)
                .foregroundColor(isCurrentMonth ? .primary : .secondary)
            
            if !taksitler.isEmpty {
                // Toplam tutar
                Text(formatCurrency(
                    amount: toplamTutar,
                    currencyCode: appSettings.currencyCode,
                    localeIdentifier: appSettings.languageCode
                ))
                .font(.system(size: 9, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .foregroundColor(.primary)
                
                // Renk kodlu çizgiler
                HStack(spacing: 1) {
                    ForEach(taksitler.prefix(3)) { taksit in
                        Rectangle()
                            .fill(taksitRengi(taksit: taksit))
                            .frame(height: 3)
                    }
                }
                .cornerRadius(1.5)
                
                // Fazla taksit göstergesi
                if taksitler.count > 3 {
                    Text("+\(taksitler.count - 3)")
                        .font(.system(size: 7))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(height: 65)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isToday ? Color.accentColor.opacity(0.1) : Color(.tertiarySystemGroupedBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isToday ? Color.accentColor : Color.clear, lineWidth: 2)
                )
        )
        .onTapGesture { // YENİ
            onTap()
        }
    }
}

struct TaksitDetaySheet: View {
    let gun: Date
    let takvimVerileri: [OdemeTakvimi]
    @EnvironmentObject var appSettings: AppSettings
    @Environment(\.dismiss) private var dismiss
    
    // Taksitleri gun'e göre hesapla
    private var taksitler: [OdemeTakvimi.TaksitOzeti] {
        takvimVerileri.first { Calendar.current.isDate($0.ay, inSameDayAs: gun) }?.taksitler ?? []
    }
    
    private var gunFormatli: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: appSettings.languageCode)
        formatter.dateFormat = "d MMMM yyyy EEEE"
        return formatter.string(from: gun)
    }
    
    private func taksitRengi(_ taksit: OdemeTakvimi.TaksitOzeti) -> Color {
        if taksit.odendiMi {
            return .green
        } else if taksit.odemeTarihi < Date() {
            return .red
        } else {
            return .orange
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if taksitler.isEmpty {
                    // Taksit yoksa
                    VStack(spacing: 20) {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        
                        Text("loan_report.no_installments_for_day")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        
                        Text(gunFormatli)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Taksit listesi
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(taksitler) { taksit in
                                HStack(spacing: 12) {
                                    // Durum çubuğu
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(taksitRengi(taksit))
                                        .frame(width: 4, height: 50)
                                    
                                    // Taksit bilgileri
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(taksit.krediAdi)
                                            .font(.headline)
                                        
                                        HStack {
                                            Text("loan_report.installment_no")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                            
                                            Text(taksit.taksitNo)
                                                .font(.caption)
                                                .fontWeight(.medium)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    // Tutar ve durum
                                    VStack(alignment: .trailing, spacing: 4) {
                                        Text(formatCurrency(
                                            amount: taksit.tutar,
                                            currencyCode: appSettings.currencyCode,
                                            localeIdentifier: appSettings.languageCode
                                        ))
                                        .font(.headline.bold())
                                        
                                        Text(taksit.odendiMi ?
                                            LocalizedStringKey("loan_report.status.paid") :
                                            taksit.odemeTarihi < Date() ?
                                            LocalizedStringKey("loan_report.status.overdue") :
                                            LocalizedStringKey("loan_report.status.pending")
                                        )
                                        .font(.caption)
                                        .foregroundColor(taksitRengi(taksit))
                                    }
                                }
                                .padding()
                                .background(Color(.secondarySystemGroupedBackground))
                                .cornerRadius(12)
                            }
                        }
                        .padding()
                    }
                    
                    // Toplam bilgi
                    HStack {
                        Text("loan_report.total_for_day")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        Text(formatCurrency(
                            amount: taksitler.reduce(0) { $0 + $1.tutar },
                            currencyCode: appSettings.currencyCode,
                            localeIdentifier: appSettings.languageCode
                        ))
                        .font(.headline.bold())
                    }
                    .padding()
                    .background(Color(.tertiarySystemGroupedBackground))
                }
            }
            .navigationTitle(gunFormatli)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("common.close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct GenelPerformansKarti: View {
    let toplamPerformans: Double
    let istatistikler: KrediIstatistikleri
    @EnvironmentObject var appSettings: AppSettings
    
    var body: some View {
        VStack(spacing: 20) {
            // Ana performans göstergesi
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 20)
                        .frame(width: 150, height: 150)
                    
                    Circle()
                        .trim(from: 0, to: toplamPerformans / 100)
                        .stroke(performansRengi, lineWidth: 20)
                        .rotationEffect(.degrees(-90))
                        .frame(width: 150, height: 150)
                    
                    VStack {
                        Text(String(format: "%.0f", toplamPerformans))
                            .font(.largeTitle.bold())
                        Text("loan_report.performance_score")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Text(performansAciklamasi)
                    .font(.headline)
                    .foregroundColor(performansRengi)
            }
            
            // İstatistikler
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                IstatistikKutu(
                    baslik: "loan_report.total_interest_paid",
                    deger: formatCurrency(
                        amount: istatistikler.toplamOdenenFaiz,
                        currencyCode: appSettings.currencyCode,
                        localeIdentifier: appSettings.languageCode
                    )
                )
                
                IstatistikKutu(
                    baslik: "loan_report.avg_monthly_payment",
                    deger: formatCurrency(
                        amount: istatistikler.aylikOrtalamaOdeme,
                        currencyCode: appSettings.currencyCode,
                        localeIdentifier: appSettings.languageCode
                    )
                )
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
    
    private var performansRengi: Color {
        switch toplamPerformans {
        case 80...100: return .green
        case 60..<80: return .orange
        default: return .red
        }
    }
    
    private var performansAciklamasi: LocalizedStringKey {
        switch toplamPerformans {
        case 80...100: return "loan_report.performance_excellent"
        case 60..<80: return "loan_report.performance_good"
        case 40..<60: return "loan_report.performance_fair"
        default: return "loan_report.performance_poor"
        }
    }
}

struct IstatistikKutu: View {
    let baslik: LocalizedStringKey
    let deger: String
    
    var body: some View {
        VStack(spacing: 8) {
            Text(baslik)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
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

struct KrediPerformansKarti: View {
    let rapor: KrediDetayRaporu
    @EnvironmentObject var appSettings: AppSettings
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(rapor.hesap.isim)
                        .font(.headline)
                    
                    Text("loan_report.payment_performance")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Performans skoru
                Text(String(format: "%.0f%%", rapor.odemePerformansi.performansSkoru))
                    .font(.title2.bold())
                    .foregroundColor(rapor.odemePerformansi.performansRengi)
            }
            
            // Detaylar
            HStack(spacing: 20) {
                PerformansDetay(
                    baslik: "loan_report.on_time",
                    sayi: rapor.odemePerformansi.zamanindaOdenenSayisi,
                    renk: .green
                )
                
                PerformansDetay(
                    baslik: "loan_report.late",
                    sayi: rapor.odemePerformansi.gecOdenenSayisi,
                    renk: .orange
                )
                
                PerformansDetay(
                    baslik: "loan_report.missed",
                    sayi: rapor.odemePerformansi.odenmeyenSayisi,
                    renk: .red
                )
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
}

struct PerformansDetay: View {
    let baslik: LocalizedStringKey
    let sayi: Int
    let renk: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text("\(sayi)")
                .font(.title3.bold())
                .foregroundColor(renk)
            
            Text(baslik)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct KrediDetayBilgileri: View {
    let detay: KrediDetaylari
    @EnvironmentObject var appSettings: AppSettings
    
    var body: some View {
        VStack(spacing: 12) {
            DetayRow(
                baslik: "loan_report.principal_amount",
                deger: formatCurrency(
                    amount: detay.cekilenTutar,
                    currencyCode: appSettings.currencyCode,
                    localeIdentifier: appSettings.languageCode
                )
            )
            
            DetayRow(
                baslik: "loan_report.interest_rate",
                deger: "\(getLocalized(detay.faizTipi.localizedKey, from: appSettings)) %\(String(format: "%.2f", detay.faizOrani))"
            )
            
            DetayRow(
                baslik: "loan_report.total_to_pay",
                deger: formatCurrency(
                    amount: detay.toplamOdenecekTutar,
                    currencyCode: appSettings.currencyCode,
                    localeIdentifier: appSettings.languageCode
                )
            )
            
            DetayRow(
                baslik: "loan_report.total_interest",
                deger: formatCurrency(
                    amount: detay.toplamFaizTutari,
                    currencyCode: appSettings.currencyCode,
                    localeIdentifier: appSettings.languageCode
                )
            )
            
            if let sonOdeme = detay.sonOdemeTarihi {
                DetayRow(
                    baslik: "loan_report.last_payment_date",
                    deger: formatDetailDate(sonOdeme)
                )
            }
        }
        .padding()
        .background(Color(.tertiarySystemGroupedBackground))
        .cornerRadius(12)
    }
    private func formatDetailDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: appSettings.languageCode)
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

struct DetayRow: View {
    let baslik: LocalizedStringKey
    let deger: String
    
    var body: some View {
        HStack {
            Text(baslik)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Text(deger)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

struct PerformansMiniKart: View {
    let performans: OdemePerformansi
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("loan_report.payment_performance")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                    Text("\(performans.zamanindaOdenenSayisi)")
                        .font(.caption)
                    
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                    Text("\(performans.gecOdenenSayisi)")
                        .font(.caption)
                    
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                        .font(.caption)
                    Text("\(performans.odenmeyenSayisi)")
                        .font(.caption)
                }
            }
            
            Spacer()
            
            // Skor
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.0f%%", performans.performansSkoru))
                    .font(.headline.bold())
                    .foregroundColor(performans.performansRengi)
                
                Text("loan_report.score")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.tertiarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

struct SonrakiTaksitKarti: View {
    let taksit: KrediTaksitDetayi
    @EnvironmentObject var appSettings: AppSettings
    
    private var kalanGun: Int {
        Calendar.current.dateComponents([.day], from: Date(), to: taksit.odemeTarihi).day ?? 0
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "calendar.badge.exclamationmark")
                    .foregroundColor(.orange)
                
                Text("loan_report.next_payment")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Text(formatCurrency(
                    amount: taksit.taksitTutari,
                    currencyCode: appSettings.currencyCode,
                    localeIdentifier: appSettings.languageCode
                ))
                .font(.headline.bold())
            }
            
            HStack {
                Text(formatDate(taksit.odemeTarihi))
                    .font(.caption)
                
                Spacer()
                
                if kalanGun > 0 {
                    Text(formatRemainingDays(kalanGun))
                        .font(.caption)
                        .foregroundColor(kalanGun <= 7 ? .orange : .secondary)
                } else if kalanGun == 0 {
                    Text("loan_report.due_today")
                        .font(.caption.bold())
                        .foregroundColor(.red)
                } else {
                    Text("loan_report.overdue")
                        .font(.caption.bold())
                        .foregroundColor(.red)
                }
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
    }
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: appSettings.languageCode)
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    private func formatRemainingDays(_ days: Int) -> String {
        let languageBundle = Bundle.getLanguageBundle(for: appSettings.languageCode)
        let formatString = languageBundle.localizedString(forKey: "loan_report.days_remaining", value: "%d days remaining", table: nil)
        return String(format: formatString, days)
    }
}

struct TaksitListesiKompakt: View {
    let rapor: KrediDetayRaporu
    let giderOlarakEklenenler: Set<UUID>
    @EnvironmentObject var appSettings: AppSettings
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("loan_report.installments_in_period")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            ForEach(rapor.donemdekiTaksitler.prefix(5)) { taksit in
                HStack {
                    Image(systemName: taksit.odendiMi ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(taksit.odendiMi ? .green : .secondary)
                        .font(.caption)
                    
                    Text(formatCompactDate(taksit.odemeTarihi))
                        .font(.caption)
                    
                    if giderOlarakEklenenler.contains(taksit.id) {
                        Image(systemName: "banknote")
                            .font(.caption2)
                            .foregroundColor(.green)
                    }
                    
                    Spacer()
                    
                    Text(formatCurrency(
                        amount: taksit.taksitTutari,
                        currencyCode: appSettings.currencyCode,
                        localeIdentifier: appSettings.languageCode
                    ))
                    .font(.caption.bold())
                    .foregroundColor(taksit.odendiMi ? .secondary : .primary)
                }
            }
            
            if rapor.donemdekiTaksitler.count > 5 {
                Text(String(format: NSLocalizedString("loan_report.more_installments", comment: ""), rapor.donemdekiTaksitler.count - 5))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.tertiarySystemGroupedBackground))
        .cornerRadius(12)
    }
    
    private func formatCompactDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: appSettings.languageCode)
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
