// Features/ReportsDetailed/Harcamalar/HarcamaRaporuComponents.swift

import SwiftUI
import Charts

// MARK: - Özet Kartı
struct HarcamaOzetKarti: View {
    let ozet: HarcamaGenelOzet
    @EnvironmentObject var appSettings: AppSettings
    @State private var animateValues = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Başlık ve toplam
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("spending_report.total_spending")
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
                
                // Değişim göstergesi
                if let degisim = ozet.oncekiDonemeGoreDegisim {
                    VStack(alignment: .trailing, spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: degisim.yuzde > 0 ? "arrow.up" : "arrow.down")
                                .font(.caption)
                            Text(String(format: "%.1f%%", abs(degisim.yuzde)))
                                .font(.caption.bold())
                        }
                        .foregroundColor(degisim.yuzde > 0 ? .red : .green)
                        
                        Text(LocalizedStringKey(degisim.aciklama))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            // Metrikler
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                MetrikMiniKart(
                    baslik: "spending_report.daily_avg",
                    deger: formatCurrency(
                        amount: ozet.gunlukOrtalama,
                        currencyCode: appSettings.currencyCode,
                        localeIdentifier: appSettings.languageCode
                    ),
                    ikon: "calendar.day.timeline.left",
                    renk: .blue
                )
                
                MetrikMiniKart(
                    baslik: "spending_report.transaction_count",
                    deger: "\(ozet.islemSayisi)",
                    ikon: "number.circle.fill",
                    renk: .green
                )
                
                MetrikMiniKart(
                    baslik: "spending_report.avg_transaction",
                    deger: formatCurrency(
                        amount: ozet.ortalamaIslemTutari,
                        currencyCode: appSettings.currencyCode,
                        localeIdentifier: appSettings.languageCode
                    ),
                    ikon: "equal.circle.fill",
                    renk: .orange
                )
            }
            
            // En yüksek harcama
            if let enYuksek = ozet.enYuksekHarcama {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("spending_report.highest_expense")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        HStack {
                            Text(enYuksek.isim)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            Text(formatCurrency(
                                amount: enYuksek.tutar,
                                currencyCode: appSettings.currencyCode,
                                localeIdentifier: appSettings.languageCode
                            ))
                            .font(.subheadline.bold())
                            .foregroundColor(.orange)
                        }
                    }
                }
                .padding()
                .background(Color.orange.opacity(0.1))
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

// MARK: - En Çok Harcanan Kategoriler
struct EnCokHarcananKategoriler: View {
    let kategoriler: [HarcamaKategoriOzet]  // TİP GÜNCELLENDİ
    @EnvironmentObject var appSettings: AppSettings
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("spending_report.top_categories")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            ForEach(kategoriler.prefix(5)) { kategori in
                HStack(spacing: 12) {
                    Image(systemName: kategori.ikonAdi)
                        .font(.title3)
                        .foregroundColor(kategori.renk)
                        .frame(width: 40, height: 40)
                        .background(kategori.renk.opacity(0.15))
                        .cornerRadius(8)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(LocalizedStringKey(kategori.localizationKey ?? kategori.isim))
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        // Progress bar
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.gray.opacity(0.1))
                                    .frame(height: 4)
                                
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(kategori.renk)
                                    .frame(width: (kategori.yuzde / 100) * geometry.size.width, height: 4)
                            }
                        }
                        .frame(height: 4)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(formatCurrency(
                            amount: kategori.tutar,
                            currencyCode: appSettings.currencyCode,
                            localeIdentifier: appSettings.languageCode
                        ))
                        .font(.subheadline.bold())
                        
                        Text(String(format: "%.1f%%", kategori.yuzde))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
}

// MARK: - Haftalık Özet Grafik
struct HaftalikOzetGrafik: View {
    let haftalikVeriler: [HarcamaHaftalikVeri]  // TİP GÜNCELLENDİ
    @EnvironmentObject var appSettings: AppSettings
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("spending_report.weekly_summary")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            if haftalikVeriler.isEmpty {
                Text("spending_report.no_data")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 150, alignment: .center)
            } else {
                Chart(haftalikVeriler) { hafta in
                    BarMark(
                        x: .value("Week", hafta.haftaBasi, unit: .weekOfYear),
                        y: .value("Total", hafta.toplamTutar)
                    )
                    .foregroundStyle(Color.blue.gradient)
                    .cornerRadius(8)
                    .annotation(position: .top) {
                        Text(formatCurrency(
                            amount: hafta.toplamTutar,
                            currencyCode: appSettings.currencyCode,
                            localeIdentifier: appSettings.languageCode
                        ))
                        .font(.caption2.bold())
                        .foregroundColor(.secondary)
                    }
                }
                .frame(height: 200)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .weekOfYear)) { value in
                        AxisValueLabel(format: .dateTime.week())
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
}

// MARK: - İçgörüler Paneli
struct IcgorulerPaneli: View {
    let icgoruler: [HarcamaIcgoru]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("spending_report.insights")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            ForEach(icgoruler) { icgoru in
                HStack(spacing: 12) {
                    Image(systemName: icgoru.tip.ikon)
                        .font(.title3)
                        .foregroundColor(icgoru.tip.renk)
                    
                    Text(icgoru.mesaj)
                        .font(.subheadline)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Spacer()
                }
                .padding()
                .background(icgoru.tip.renk.opacity(0.1))
                .cornerRadius(12)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
}

// MARK: - Kategori Dağılım Grafiği
struct KategoriDagilimGrafigi: View {
    let kategoriler: [HarcamaKategoriDetay]  // TİP GÜNCELLENDİ
    @EnvironmentObject var appSettings: AppSettings
    @State private var secilenKategori: HarcamaKategoriDetay?  // TİP GÜNCELLENDİ
    
    private var toplamTutar: Double {
        kategoriler.reduce(0) { $0 + $1.toplamTutar }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("spending_report.category_distribution")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            HStack(alignment: .top, spacing: 20) {
                // Donut Chart
                Chart(kategoriler) { kategori in
                    SectorMark(
                        angle: .value("Amount", kategori.toplamTutar),
                        innerRadius: .ratio(0.618),
                        angularInset: 1.5
                    )
                    .foregroundStyle(kategori.renk)
                    .cornerRadius(8)
                    .opacity(secilenKategori == nil || secilenKategori?.id == kategori.id ? 1 : 0.5)
                }
                .frame(width: 200, height: 200)
                .chartBackground { chartProxy in
                    GeometryReader { geometry in
                        if let anchor = chartProxy.plotFrame {
                            let frame = geometry[anchor]
                            VStack {
                                if let kategori = secilenKategori {
                                    Text(LocalizedStringKey(kategori.localizationKey ?? kategori.isim))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(formatCurrency(
                                        amount: kategori.toplamTutar,
                                        currencyCode: appSettings.currencyCode,
                                        localeIdentifier: appSettings.languageCode
                                    ))
                                    .font(.headline.bold())
                                } else {
                                    Text("common.total")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(formatCurrency(
                                        amount: toplamTutar,
                                        currencyCode: appSettings.currencyCode,
                                        localeIdentifier: appSettings.languageCode
                                    ))
                                    .font(.headline.bold())
                                }
                            }
                            .position(x: frame.midX, y: frame.midY)
                        }
                    }
                }
                
                // Kategori listesi
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(kategoriler.prefix(10)) { kategori in
                            Button(action: {
                                withAnimation {
                                    secilenKategori = secilenKategori?.id == kategori.id ? nil : kategori
                                }
                            }) {
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(kategori.renk)
                                        .frame(width: 12, height: 12)
                                    
                                    Text(LocalizedStringKey(kategori.localizationKey ?? kategori.isim))
                                        .font(.caption)
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                    
                                    Spacer()
                                    
                                    Text(String(format: "%.1f%%", kategori.yuzde))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
}

// MARK: - Kategori Detay Kartı
struct KategoriDetayKarti: View {
    let kategori: HarcamaKategoriDetay  // TİP GÜNCELLENDİ
    let isExpanded: Bool
    let onToggle: () -> Void
    @EnvironmentObject var appSettings: AppSettings
    
    var body: some View {
        VStack(spacing: 0) {
            Button(action: onToggle) {
                HStack {
                    Image(systemName: kategori.ikonAdi)
                        .font(.title2)
                        .foregroundColor(kategori.renk)
                        .frame(width: 44, height: 44)
                        .background(kategori.renk.opacity(0.15))
                        .cornerRadius(10)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(LocalizedStringKey(kategori.localizationKey ?? kategori.isim))
                            .font(.headline)
                        
                        HStack(spacing: 12) {
                            Label("\(kategori.islemSayisi)", systemImage: "number")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            Label(String(format: "%.1f%%", kategori.yuzde), systemImage: "percent")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(formatCurrency(
                            amount: kategori.toplamTutar,
                            currencyCode: appSettings.currencyCode,
                            localeIdentifier: appSettings.languageCode
                        ))
                        .font(.headline.bold())
                        
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                VStack(spacing: 16) {
                    Divider()
                    
                    // Mini istatistikler
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("spending_report.avg_per_transaction")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(formatCurrency(
                                amount: kategori.ortalamaIslemTutari,
                                currencyCode: appSettings.currencyCode,
                                localeIdentifier: appSettings.languageCode
                            ))
                            .font(.subheadline.bold())
                        }
                        
                        Spacer()
                        
                        if let enBuyuk = kategori.enBuyukIslem {
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("spending_report.largest_expense")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(formatCurrency(
                                    amount: enBuyuk.tutar,
                                    currencyCode: appSettings.currencyCode,
                                    localeIdentifier: appSettings.languageCode
                                ))
                                .font(.subheadline.bold())
                                .foregroundColor(.orange)
                            }
                        }
                    }
                    
                    // Mini trend grafiği
                    if !kategori.gunlukDagilim.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("spending_report.daily_trend")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            Chart(kategori.gunlukDagilim) { gun in
                                LineMark(
                                    x: .value("Date", gun.gun),
                                    y: .value("Amount", gun.tutar)
                                )
                                .foregroundStyle(kategori.renk)
                                .interpolationMethod(.catmullRom)
                                
                                AreaMark(
                                    x: .value("Date", gun.gun),
                                    y: .value("Amount", gun.tutar)
                                )
                                .foregroundStyle(kategori.renk.opacity(0.1))
                                .interpolationMethod(.catmullRom)
                            }
                            .frame(height: 60)
                            .chartXAxis(.hidden)
                            .chartYAxis(.hidden)
                        }
                    }
                }
                .padding()
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
}

// MARK: - Günlük Harcama Trendi
struct GunlukHarcamaTrendi: View {
    let gunlukVeriler: [HarcamaGunlukVeri]  // TİP GÜNCELLENDİ
    @EnvironmentObject var appSettings: AppSettings
    @State private var secilenGun: Date?
    
    private var toplamHarcama: Double {
        gunlukVeriler.reduce(0) { $0 + $1.tutar }
    }
    
    private var ortalamaHarcama: Double {
        guard !gunlukVeriler.isEmpty else { return 0 }
        return toplamHarcama / Double(gunlukVeriler.count)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("spending_report.daily_trend")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("common.average")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(formatCurrency(
                        amount: ortalamaHarcama,
                        currencyCode: appSettings.currencyCode,
                        localeIdentifier: appSettings.languageCode
                    ))
                    .font(.caption.bold())
                }
            }
            
            Chart(gunlukVeriler) { gun in
                BarMark(
                    x: .value("Date", gun.gun, unit: .day),
                    y: .value("Amount", gun.tutar)
                )
                .foregroundStyle(gun.tutar > ortalamaHarcama ? Color.red.gradient : Color.blue.gradient)
                .cornerRadius(4)
                
                if let secilen = secilenGun, Calendar.current.isDate(gun.gun, inSameDayAs: secilen) {
                    RuleMark(x: .value("Selected", gun.gun))
                        .foregroundStyle(.gray.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [4, 4]))
                        .annotation(position: .top) {
                            VStack(spacing: 4) {
                                Text(gun.gun, format: .dateTime.day().month())
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(formatCurrency(
                                    amount: gun.tutar,
                                    currencyCode: appSettings.currencyCode,
                                    localeIdentifier: appSettings.languageCode
                                ))
                                .font(.caption.bold())
                            }
                            .padding(8)
                            .background(Color(.systemBackground))
                            .cornerRadius(8)
                            .shadow(radius: 2)
                        }
                }
                
                // Ortalama çizgisi
                RuleMark(y: .value("Average", ortalamaHarcama))
                    .foregroundStyle(.orange.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))
            }
            .frame(height: 200)
            .chartXSelection(value: $secilenGun)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
}

// MARK: - Hafta İçi vs Hafta Sonu
struct HaftaIciSonuKarsilastirma: View {
    let veriler: HarcamaHaftaKarsilastirma  // TİP GÜNCELLENDİ
    @EnvironmentObject var appSettings: AppSettings
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("spending_report.weekday_weekend")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            HStack(spacing: 20) {
                // Hafta içi
                VStack(spacing: 12) {
                    Image(systemName: "briefcase.fill")
                        .font(.title)
                        .foregroundColor(.blue)
                    
                    Text("spending_report.weekday")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text(formatCurrency(
                        amount: veriler.haftaIciToplam,
                        currencyCode: appSettings.currencyCode,
                        localeIdentifier: appSettings.languageCode
                    ))
                    .font(.headline.bold())
                    
                    VStack(spacing: 4) {
                        Text("\(veriler.haftaIciIslemSayisi)")
                            .font(.caption.bold())
                        Text("common.transactions")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    
                    Divider()
                    
                    VStack(spacing: 4) {
                        Text(formatCurrency(
                            amount: veriler.haftaIciOrtalama,
                            currencyCode: appSettings.currencyCode,
                            localeIdentifier: appSettings.languageCode
                        ))
                        .font(.caption.bold())
                        Text("common.average")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
                
                // Hafta sonu
                VStack(spacing: 12) {
                    Image(systemName: "beach.umbrella.fill")
                        .font(.title)
                        .foregroundColor(.orange)
                    
                    Text("spending_report.weekend")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text(formatCurrency(
                        amount: veriler.haftaSonuToplam,
                        currencyCode: appSettings.currencyCode,
                        localeIdentifier: appSettings.languageCode
                    ))
                    .font(.headline.bold())
                    
                    VStack(spacing: 4) {
                        Text("\(veriler.haftaSonuIslemSayisi)")
                            .font(.caption.bold())
                        Text("common.transactions")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    
                    Divider()
                    
                    VStack(spacing: 4) {
                        Text(formatCurrency(
                            amount: veriler.haftaSonuOrtalama,
                            currencyCode: appSettings.currencyCode,
                            localeIdentifier: appSettings.languageCode
                        ))
                        .font(.caption.bold())
                        Text("common.average")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(12)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
}

// MARK: - Saatlik Dağılım Grafiği
struct SaatlikDagilimGrafigi: View {
    let saatlikVeriler: [HarcamaSaatlikVeri]  // TİP GÜNCELLENDİ
    @EnvironmentObject var appSettings: AppSettings
    
    private var enYogunSaatler: [Int] {
        saatlikVeriler
            .sorted { $0.toplamTutar > $1.toplamTutar }
            .prefix(3)
            .map { $0.saat }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("spending_report.hourly_distribution")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            // Bar chart
            Chart(saatlikVeriler) { veri in
                BarMark(
                    x: .value("Hour", "\(veri.saat):00"),
                    y: .value("Amount", veri.toplamTutar)
                )
                .foregroundStyle(enYogunSaatler.contains(veri.saat) ? Color.orange.gradient : Color.blue.gradient)
                .cornerRadius(4)
            }
            .frame(height: 150)
            .chartXAxis {
                AxisMarks(values: .stride(by: 3)) { value in
                    AxisValueLabel()
                        .font(.caption2)
                }
            }
            
            // En yoğun saatler
            if !enYogunSaatler.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "clock.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                    
                    Text("spending_report.busiest_hours")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text(enYogunSaatler.map { "\($0):00" }.joined(separator: ", "))
                        .font(.caption.bold())
                }
                .padding(.horizontal)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
}

// MARK: - Önceki Dönem Karşılaştırma
struct OncekiDonemKarsilastirma: View {
    let karsilastirma: HarcamaDonemKarsilastirma  // TİP GÜNCELLENDİ
    @EnvironmentObject var appSettings: AppSettings
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("spending_report.period_comparison")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            HStack(spacing: 16) {
                // Önceki dönem
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Circle()
                            .fill(Color.gray)
                            .frame(width: 12, height: 12)
                        Text("spending_report.previous_period")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Text(formatCurrency(
                        amount: karsilastirma.oncekiDonemToplam,
                        currencyCode: appSettings.currencyCode,
                        localeIdentifier: appSettings.languageCode
                    ))
                    .font(.headline)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Ok işareti
                Image(systemName: "arrow.right")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                
                // Mevcut dönem
                VStack(alignment: .trailing, spacing: 8) {
                    HStack {
                        Text("spending_report.current_period")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 12, height: 12)
                    }
                    
                    Text(formatCurrency(
                        amount: karsilastirma.buDonemToplam,
                        currencyCode: appSettings.currencyCode,
                        localeIdentifier: appSettings.languageCode
                    ))
                    .font(.headline)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            
            // Değişim göstergesi
            HStack {
                Image(systemName: karsilastirma.degisimYuzdesi > 0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                    .font(.title2)
                    .foregroundColor(karsilastirma.degisimYuzdesi > 0 ? .red : .green)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(formatCurrency(
                            amount: abs(karsilastirma.degisimTutari),
                            currencyCode: appSettings.currencyCode,
                            localeIdentifier: appSettings.languageCode
                        ))
                        .font(.headline.bold())
                        
                        Text("(\(String(format: "%.1f%%", abs(karsilastirma.degisimYuzdesi))))")
                            .font(.headline)
                            .foregroundColor(karsilastirma.degisimYuzdesi > 0 ? .red : .green)
                    }
                    
                    Text(karsilastirma.degisimYuzdesi > 0 ? "spending_report.increase" : "spending_report.decrease")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            .padding()
            .background((karsilastirma.degisimYuzdesi > 0 ? Color.red : Color.green).opacity(0.1))
            .cornerRadius(12)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
}

// MARK: - Kategori Değişim Tablosu
struct KategoriDegisimTablosu: View {
    let degisimler: [HarcamaKategoriDegisim]  // TİP GÜNCELLENDİ
    @EnvironmentObject var appSettings: AppSettings
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("spending_report.category_changes")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            VStack(spacing: 8) {
                ForEach(degisimler.prefix(5)) { degisim in
                    HStack {
                        Image(systemName: degisim.kategori.ikonAdi)
                            .font(.callout)
                            .foregroundColor(degisim.kategori.renk)
                            .frame(width: 30, height: 30)
                            .background(degisim.kategori.renk.opacity(0.15))
                            .cornerRadius(6)
                        
                        Text(LocalizedStringKey(degisim.kategori.localizationKey ?? degisim.kategori.isim))
                            .font(.subheadline)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            HStack(spacing: 4) {
                                Image(systemName: degisim.degisimYuzdesi > 0 ? "arrow.up" : "arrow.down")
                                    .font(.caption2)
                                Text(String(format: "%.1f%%", abs(degisim.degisimYuzdesi)))
                                    .font(.caption.bold())
                            }
                            .foregroundColor(degisim.degisimYuzdesi > 0 ? .red : .green)
                            
                            Text(formatCurrency(
                                amount: degisim.mevcutTutar,
                                currencyCode: appSettings.currencyCode,
                                localeIdentifier: appSettings.languageCode
                            ))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 6)
                    
                    if degisim.id != degisimler.prefix(5).last?.id {
                        Divider()
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
}

// MARK: - Bütçe Performans Kartı
struct ButcePerformansKarti: View {
    let performanslar: [HarcamaButcePerformans]  // TİP GÜNCELLENDİ
    @EnvironmentObject var appSettings: AppSettings
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("spending_report.budget_performance")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            ForEach(performanslar) { performans in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(performans.butce.isim)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        HStack(spacing: 4) {
                            Circle()
                                .fill(performans.durum.renk)
                                .frame(width: 8, height: 8)
                            
                            Text(performans.durum == .normal ?
                                LocalizedStringKey("spending_report.budget_status.normal") :
                                performans.durum == .kritik ?
                                LocalizedStringKey("spending_report.budget_status.critical") :
                                LocalizedStringKey("spending_report.budget_status.exceeded"))
                                .font(.caption)
                                .foregroundColor(performans.durum.renk)
                        }
                    }
                    
                    // Progress bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 8)
                            
                            RoundedRectangle(cornerRadius: 4)
                                .fill(performans.durum.renk)
                                .frame(width: min((performans.kullanimOrani / 100) * geometry.size.width, geometry.size.width), height: 8)
                        }
                    }
                    .frame(height: 8)
                    
                    HStack {
                        Text(formatCurrency(
                            amount: performans.harcananTutar,
                            currencyCode: appSettings.currencyCode,
                            localeIdentifier: appSettings.languageCode
                        ))
                        .font(.caption)
                        
                        Spacer()
                        
                        Text(String(format: "%.0f%%", performans.kullanimOrani))
                            .font(.caption.bold())
                        
                        Spacer()
                        
                        Text(formatCurrency(
                            amount: performans.butce.limitTutar,
                            currencyCode: appSettings.currencyCode,
                            localeIdentifier: appSettings.languageCode
                        ))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .background(performans.durum.renk.opacity(0.05))
                .cornerRadius(12)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
}

// MARK: - Yardımcı View'lar
struct MetrikMiniKart: View {
    let baslik: LocalizedStringKey
    let deger: String
    let ikon: String
    let renk: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: ikon)
                .font(.title3)
                .foregroundColor(renk)
            
            Text(deger)
                .font(.callout.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            
            Text(baslik)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.tertiarySystemGroupedBackground))
        .cornerRadius(12)
    }
}
