import SwiftUI
import Charts

struct NakitAkisiRaporView: View {
    @EnvironmentObject var appSettings: AppSettings
    let veri: NakitAkisRaporVerisi
    
    @State private var secilenGun: Date?
    @State private var gunDetayGoster = false
    @State private var hoveredDate: Date?
    @State private var dragLocation: CGPoint = .zero
    @State private var showTooltip = false
    
    private var chartData: [NakitAkisVerisi] {
        veri.gunlukVeriler
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Özet Kartları
                ozetKartlari
                
                // Ana Grafik
                anaGrafik
                    .frame(height: 300)
                    .padding(.horizontal)
                
                // Kümülatif Bakiye Grafiği
                kumulatifGrafik
                    .frame(height: 200)
                    .padding(.horizontal)
                
                // Günlük Detay Listesi
                gunlukDetayListesi
            }
            .padding(.vertical)
        }
        .sheet(isPresented: $gunDetayGoster) {
            if let tarih = secilenGun {
                GunDetayView(secilenTarih: tarih)
                    .environmentObject(appSettings)
            }
        }
    }
    
    // MARK: - Özet Kartları
    private var ozetKartlari: some View {
        HStack(spacing: 16) {
            OzetKartView(
                baslik: "detailed_reports.cash_flow.total_income",
                tutar: veri.toplamGelir,
                renk: .green,
                ikon: "arrow.down.circle.fill"
            )
            
            OzetKartView(
                baslik: "detailed_reports.cash_flow.total_expense",
                tutar: veri.toplamGider,
                renk: .red,
                ikon: "arrow.up.circle.fill"
            )
            
            OzetKartView(
                baslik: "detailed_reports.cash_flow.net_flow",
                tutar: veri.netAkis,
                renk: veri.netAkis >= 0 ? .blue : .orange,
                ikon: "chart.line.uptrend.xyaxis"
            )
        }
        .padding(.horizontal)
    }
    
    // MARK: - Ana Grafik
    private var anaGrafik: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("detailed_reports.cash_flow.daily_chart")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Chart(chartData) { item in
                // Gelir Çizgisi
                LineMark(
                    x: .value("Tarih", item.tarih),
                    y: .value("Tutar", item.gelir)
                )
                .foregroundStyle(.green)
                .symbol(.circle)
                .symbolSize(30)
                .lineStyle(StrokeStyle(lineWidth: 2))
                
                // Gider Çizgisi
                LineMark(
                    x: .value("Tarih", item.tarih),
                    y: .value("Tutar", item.gider)
                )
                .foregroundStyle(.red)
                .symbol(.square)
                .symbolSize(30)
                .lineStyle(StrokeStyle(lineWidth: 2))
                
                // Net Akış Çizgisi
                LineMark(
                    x: .value("Tarih", item.tarih),
                    y: .value("Tutar", item.netAkis)
                )
                .foregroundStyle(.blue)
                .symbol(.diamond)
                .symbolSize(30)
                .lineStyle(StrokeStyle(lineWidth: 3))
                
                // Hover efekti için görünmez alan
                if let hoveredDate = hoveredDate {
                    RuleMark(x: .value("Tarih", hoveredDate))
                        .foregroundStyle(.gray.opacity(0.3))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: calculateStride())) { _ in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel {
                        if let val = value.as(Double.self) {
                            Text(formatCurrency(
                                amount: val,
                                currencyCode: appSettings.currencyCode,
                                localeIdentifier: appSettings.languageCode
                            ))
                        }
                    }
                }
            }
            .chartLegend(position: .top, alignment: .center) {
                HStack(spacing: 20) {
                    Label("common.income", systemImage: "circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                    
                    Label("common.expense", systemImage: "square.fill")
                        .foregroundColor(.red)
                        .font(.caption)
                    
                    Label("detailed_reports.cash_flow.net", systemImage: "diamond.fill")
                        .foregroundColor(.blue)
                        .font(.caption)
                }
            }
            .overlay(alignment: .topLeading) {
                if showTooltip, let hoveredDate = hoveredDate,
                   let data = chartData.first(where: { Calendar.current.isDate($0.tarih, sameDayAs: hoveredDate) }) {
                    TooltipView(data: data, appSettings: appSettings)
                        .position(x: min(max(100, dragLocation.x), 250),
                                y: min(max(50, dragLocation.y - 20), 200))
                }
            }
            .chartBackground { chartProxy in
                GeometryReader { geometry in
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .onContinuousHover { phase in
                            switch phase {
                            case .active(let location):
                                dragLocation = location
                                showTooltip = true
                                if let date = getDateFromLocation(
                                    location: location,
                                    geometry: geometry,
                                    chartProxy: chartProxy
                                ) {
                                    withAnimation(.easeInOut(duration: 0.1)) {
                                        hoveredDate = date
                                    }
                                }
                            case .ended:
                                withAnimation(.easeOut(duration: 0.2)) {
                                    showTooltip = false
                                    hoveredDate = nil
                                }
                            }
                        }
                        .onTapGesture { location in
                            if let date = getDateFromLocation(
                                location: location,
                                geometry: geometry,
                                chartProxy: chartProxy
                            ) {
                                secilenGun = date
                                gunDetayGoster = true
                            }
                        }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }
    
    // MARK: - Kümülatif Grafik
    private var kumulatifGrafik: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("detailed_reports.cash_flow.cumulative_balance")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Chart(chartData) { item in
                AreaMark(
                    x: .value("Tarih", item.tarih),
                    y: .value("Bakiye", item.kumulatifBakiye)
                )
                .foregroundStyle(
                    .linearGradient(
                        colors: [
                            item.kumulatifBakiye >= 0 ? .blue.opacity(0.3) : .red.opacity(0.3),
                            item.kumulatifBakiye >= 0 ? .blue.opacity(0.1) : .red.opacity(0.1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                
                LineMark(
                    x: .value("Tarih", item.tarih),
                    y: .value("Bakiye", item.kumulatifBakiye)
                )
                .foregroundStyle(item.kumulatifBakiye >= 0 ? .blue : .red)
                .lineStyle(StrokeStyle(lineWidth: 2))
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: calculateStride())) { _ in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel {
                        if let val = value.as(Double.self) {
                            Text(formatCurrency(
                                amount: val,
                                currencyCode: appSettings.currencyCode,
                                localeIdentifier: appSettings.languageCode
                            ))
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }
    
    // MARK: - Günlük Detay Listesi
    private var gunlukDetayListesi: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("detailed_reports.cash_flow.daily_summary")
                .font(.headline)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            LazyVStack(spacing: 8) {
                ForEach(chartData.reversed()) { item in
                    GunlukOzetSatiri(veri: item, appSettings: appSettings) {
                        secilenGun = item.tarih
                        gunDetayGoster = true
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Helper Functions
    private func calculateStride() -> Int {
        let gunSayisi = chartData.count
        if gunSayisi <= 7 { return 1 }
        if gunSayisi <= 14 { return 2 }
        if gunSayisi <= 30 { return 5 }
        return 7
    }
    
    private func getDateFromLocation(location: CGPoint, geometry: GeometryProxy, chartProxy: ChartProxy) -> Date? {
        let frame = geometry.frame(in: .local)
        let xPosition = location.x - frame.minX
        let percentage = xPosition / frame.width
        
        guard let firstDate = chartData.first?.tarih,
              let lastDate = chartData.last?.tarih else { return nil }
        
        let totalInterval = lastDate.timeIntervalSince(firstDate)
        let targetInterval = totalInterval * Double(percentage)
        let targetDate = firstDate.addingTimeInterval(targetInterval)
        
        // En yakın günü bul
        return chartData.min(by: {
            abs($0.tarih.timeIntervalSince(targetDate)) < abs($1.tarih.timeIntervalSince(targetDate))
        })?.tarih
    }
}

// MARK: - Alt Bileşenler

struct OzetKartView: View {
    let baslik: LocalizedStringKey
    let tutar: Double
    let renk: Color
    let ikon: String
    @EnvironmentObject var appSettings: AppSettings
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: ikon)
                    .font(.title2)
                    .foregroundColor(renk)
                Spacer()
            }
            
            Text(baslik)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text(formatCurrency(
                amount: tutar,
                currencyCode: appSettings.currencyCode,
                localeIdentifier: appSettings.languageCode
            ))
            .font(.title3.bold())
            .foregroundColor(renk)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(renk.opacity(0.1))
        .cornerRadius(12)
    }
}

struct TooltipView: View {
    let data: NakitAkisVerisi
    let appSettings: AppSettings
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(data.tarih.formatted(date: .abbreviated, time: .omitted))
                .font(.caption.bold())
            
            HStack {
                Text("common.income")
                    .foregroundColor(.green)
                Spacer()
                Text(formatCurrency(
                    amount: data.gelir,
                    currencyCode: appSettings.currencyCode,
                    localeIdentifier: appSettings.languageCode
                ))
            }
            .font(.caption)
            
            HStack {
                Text("common.expense")
                    .foregroundColor(.red)
                Spacer()
                Text(formatCurrency(
                    amount: data.gider,
                    currencyCode: appSettings.currencyCode,
                    localeIdentifier: appSettings.languageCode
                ))
            }
            .font(.caption)
            
            Divider()
            
            HStack {
                Text("detailed_reports.cash_flow.net")
                    .foregroundColor(.blue)
                    .bold()
                Spacer()
                Text(formatCurrency(
                    amount: data.netAkis,
                    currencyCode: appSettings.currencyCode,
                    localeIdentifier: appSettings.languageCode
                ))
                .bold()
            }
            .font(.caption)
        }
        .padding(8)
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(radius: 4)
    }
}

struct GunlukOzetSatiri: View {
    let veri: NakitAkisVerisi
    let appSettings: AppSettings
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading) {
                    Text(veri.tarih.formatted(date: .abbreviated, time: .omitted))
                        .font(.subheadline.bold())
                    
                    HStack(spacing: 16) {
                        Label(
                            formatCurrency(
                                amount: veri.gelir,
                                currencyCode: appSettings.currencyCode,
                                localeIdentifier: appSettings.languageCode
                            ),
                            systemImage: "arrow.down.circle"
                        )
                        .foregroundColor(.green)
                        .font(.caption)
                        
                        Label(
                            formatCurrency(
                                amount: veri.gider,
                                currencyCode: appSettings.currencyCode,
                                localeIdentifier: appSettings.languageCode
                            ),
                            systemImage: "arrow.up.circle"
                        )
                        .foregroundColor(.red)
                        .font(.caption)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("detailed_reports.cash_flow.net")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(formatCurrency(
                        amount: veri.netAkis,
                        currencyCode: appSettings.currencyCode,
                        localeIdentifier: appSettings.languageCode
                    ))
                    .font(.subheadline.bold())
                    .foregroundColor(veri.netAkis >= 0 ? .blue : .orange)
                }
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }
}
