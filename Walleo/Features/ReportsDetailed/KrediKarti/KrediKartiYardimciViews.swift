//
//  KartSeciciChip.swift
//  Walleo
//
//  Created by Mustafa Turan on 15.07.2025.
//


// >> YENİ DOSYA: Features/ReportsDetailed/Views/KrediKartiYardimciViews.swift

import SwiftUI

// Kart seçici chip
struct KartSeciciChip: View {
    let hesap: Hesap
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: hesap.ikonAdi)
                .font(.callout)
                .foregroundColor(isSelected ? .white : hesap.renk)
            
            Text(hesap.isim)
                .font(.subheadline.bold())
                .foregroundColor(isSelected ? .white : .primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            isSelected ? hesap.renk : Color(.tertiarySystemGroupedBackground)
        )
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(isSelected ? Color.clear : hesap.renk.opacity(0.3), lineWidth: 1)
        )
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(response: 0.3), value: isSelected)
    }
}

// Kart özet kartı
struct KartOzetKarti: View {
    let rapor: KartDetayRaporu
    let isSelected: Bool
    let namespace: Namespace.ID
    @EnvironmentObject var appSettings: AppSettings
    
    var body: some View {
        HStack(spacing: 16) {
            // Kart ikonu
            Image(systemName: rapor.hesap.ikonAdi)
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 50, height: 50)
                .background(rapor.hesap.renk)
                .cornerRadius(12)
                .matchedGeometryEffect(id: "icon-\(rapor.id)", in: namespace)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(rapor.hesap.isim)
                    .font(.headline)
                    .matchedGeometryEffect(id: "title-\(rapor.id)", in: namespace)
                
                HStack {
                    Text(formatCurrency(
                        amount: rapor.toplamHarcama,
                        currencyCode: appSettings.currencyCode,
                        localeIdentifier: appSettings.languageCode
                    ))
                    .font(.subheadline.bold())
                    .foregroundColor(.red)
                    
                    Text("•")
                        .foregroundColor(.secondary)
                    
                    Text("\(Int((rapor.guncelBorc / rapor.limit) * 100))%")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Mini limit göstergesi
            CircularProgressView(
                progress: min(rapor.guncelBorc / rapor.limit, 1.0),
                lineWidth: 4,
                color: colorForUsage(rapor.guncelBorc / rapor.limit)
            )
            .frame(width: 40, height: 40)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
                .shadow(
                    color: isSelected ? rapor.hesap.renk.opacity(0.3) : Color.black.opacity(0.05),
                    radius: isSelected ? 10 : 5,
                    y: isSelected ? 5 : 2
                )
        )
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.spring(response: 0.3), value: isSelected)
    }
    
    private func colorForUsage(_ usage: Double) -> Color {
        switch usage {
        case 0..<0.5: return .green
        case 0.5..<0.8: return .orange
        default: return .red
        }
    }
}

// Dairesel ilerleme göstergesi
struct CircularProgressView: View {
    let progress: Double
    let lineWidth: CGFloat
    let color: Color
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: lineWidth)
            
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(), value: progress)
        }
    }
}

// İstatistik kartı
struct StatistikKarti: View {
    let ikon: String
    let baslikKey: String
    let deger: String
    let renk: Color
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: ikon)
                .font(.title2)
                .foregroundColor(renk)
            
            VStack(spacing: 4) {
                Text(LocalizedStringKey(baslikKey))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(deger)
                    .font(.headline.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

// En yüksek harcama kartı
struct EnYuksekHarcamaKarti: View {
    let islem: Islem
    @EnvironmentObject var appSettings: AppSettings
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(LocalizedStringKey("reports.credit_card.highest_transaction"), systemImage: "arrow.up.circle.fill")
                .font(.headline)
                .foregroundColor(.red)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(islem.isim)
                        .font(.subheadline.bold())
                    
                    HStack(spacing: 8) {
                        if let kategori = islem.kategori {
                            Label(
                                LocalizedStringKey(kategori.localizationKey ?? kategori.isim),
                                systemImage: kategori.ikonAdi
                            )
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                        
                        Text(islem.tarih, format: .dateTime.day().month())
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Text(formatCurrency(
                    amount: islem.tutar,
                    currencyCode: appSettings.currencyCode,
                    localeIdentifier: appSettings.languageCode
                ))
                .font(.title3.bold())
                .foregroundColor(.red)
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color.red.opacity(0.1), Color.red.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(12)
    }
}

// Kategori trend kartı
struct KategoriTrendKarti: View {
    let trend: KategoriTrend
    @EnvironmentObject var appSettings: AppSettings
    @State private var genisletildi = false
    
    var body: some View {
        VStack(spacing: 0) {
            Button(action: {
                withAnimation(.spring(response: 0.3)) {
                    genisletildi.toggle()
                }
            }) {
                HStack(spacing: 12) {
                    Image(systemName: trend.kategori.ikonAdi)
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(trend.kategori.renk)
                        .cornerRadius(8)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(LocalizedStringKey(trend.kategori.localizationKey ?? trend.kategori.isim))
                            .font(.subheadline.bold())
                            .foregroundColor(.primary)
                        
                        HStack(spacing: 4) {
                            Image(systemName: trend.trend.ikon)
                                .font(.caption)
                                .foregroundColor(trend.trend.renk)
                            
                            Text("\(trend.degisimYuzdesi > 0 ? "+" : "")\(Int(trend.degisimYuzdesi))%")
                                .font(.caption.bold())
                                .foregroundColor(trend.trend.renk)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(formatCurrency(
                            amount: trend.buAy,
                            currencyCode: appSettings.currencyCode,
                            localeIdentifier: appSettings.languageCode
                        ))
                        .font(.subheadline.bold())
                        
                        Image(systemName: genisletildi ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .buttonStyle(.plain)
            .padding()
            
            if genisletildi {
                VStack(spacing: 8) {
                    Divider()
                    
                    HStack {
                        VStack(alignment: .leading) {
                            Text(LocalizedStringKey("reports.credit_card.previous_month"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(formatCurrency(
                                amount: trend.oncekiAy,
                                currencyCode: appSettings.currencyCode,
                                localeIdentifier: appSettings.languageCode
                            ))
                            .font(.subheadline)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "arrow.right")
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text(LocalizedStringKey("reports.credit_card.current_month"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(formatCurrency(
                                amount: trend.buAy,
                                currencyCode: appSettings.currencyCode,
                                localeIdentifier: appSettings.languageCode
                            ))
                            .font(.subheadline.bold())
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

// Mini trend grafiği
struct MiniTrendGrafik: View {
    let ortalama: Double
    let animasyonTamamlandi: Bool
    
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let width = geometry.size.width
                let height = geometry.size.height
                let midY = height / 2
                
                // Rastgele dalgalı bir çizgi oluştur
                path.move(to: CGPoint(x: 0, y: midY))
                
                for i in stride(from: 0, through: width, by: width / 10) {
                    let variation = Double.random(in: -height/4...height/4)
                    let y = midY + variation
                    path.addLine(to: CGPoint(x: i, y: animasyonTamamlandi ? y : midY))
                }
            }
            .trim(from: 0, to: animasyonTamamlandi ? 1 : 0)
            .stroke(
                LinearGradient(
                    colors: [Color.blue.opacity(0.5), Color.blue],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
            )
            .animation(.easeOut(duration: 1.5), value: animasyonTamamlandi)
            
            // Ortalama çizgisi
            Path { path in
                path.move(to: CGPoint(x: 0, y: geometry.size.height / 2))
                path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height / 2))
            }
            .stroke(Color.gray.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [5, 3]))
        }
    }
}

// İçgörü kartı
struct IcgoruKarti: View {
    let icgoru: KrediKartiIcgorusu
    let isExpanded: Bool
    @EnvironmentObject var appSettings: AppSettings
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Text(icgoru.ikon)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(formatInsightMessage())
                        .font(.subheadline.bold())
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    if let actionKey = icgoru.actionKey {
                        Text(LocalizedStringKey(actionKey))
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                
                Spacer()
                
                if isExpanded {
                    Image(systemName: "chevron.up.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
            
            if isExpanded {
                // Detaylı bilgi veya aksiyonlar
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                    
                    Text(LocalizedStringKey("reports.credit_card.insight.more_info"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    // Burada daha fazla detay veya aksiyon butonları olabilir
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemGroupedBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isExpanded ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 2)
                )
        )
        .scaleEffect(isExpanded ? 1.02 : 1.0)
        .animation(.spring(response: 0.3), value: isExpanded)
    }
    
    private func formatInsightMessage() -> String {
        var message = NSLocalizedString(icgoru.mesajKey, comment: "")
        
        // Parametreleri yerine koy
        for (key, value) in icgoru.parametreler {
            if let stringValue = value as? String {
                message = message.replacingOccurrences(of: "%@", with: stringValue)
            } else if let intValue = value as? Int {
                message = message.replacingOccurrences(of: "%d", with: "\(intValue)")
            }
        }
        
        return message
    }
}

// En sık harcama günü kartı
struct EnSikHarcamaGunuKarti: View {
    let gunAnalizi: GunAnalizi
    let animasyonTamamlandi: Bool
    @EnvironmentObject var appSettings: AppSettings
    
    @State private var displayedPercentage: Double = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(LocalizedStringKey("reports.credit_card.busiest_spending_day"))
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text(gunAnalizi.gun)
                        .font(.title.bold())
                }
                
                Spacer()
                
                // Animasyonlu yüzde göstergesi
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 6)
                        .frame(width: 60, height: 60)
                    
                    Circle()
                        .trim(from: 0, to: animasyonTamamlandi ? displayedPercentage / 100 : 0)
                        .stroke(
                            LinearGradient(
                                colors: [Color.purple, Color.pink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 1.0), value: animasyonTamamlandi)
                    
                    Text("\(Int(displayedPercentage))%")
                        .font(.caption.bold())
                        .contentTransition(.numericText())
                }
            }
            
            // Ortalama harcama
            HStack {
                Label(LocalizedStringKey("reports.credit_card.average_on_this_day"), systemImage: "chart.bar.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(formatCurrency(
                    amount: gunAnalizi.ortalamaTutar,
                    currencyCode: appSettings.currencyCode,
                    localeIdentifier: appSettings.languageCode
                ))
                .font(.subheadline.bold())
            }
            .padding()
            .background(Color(.tertiarySystemGroupedBackground))
            .cornerRadius(8)
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color.purple.opacity(0.1), Color.pink.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                displayedPercentage = gunAnalizi.yuzde
            }
        }
    }
}

// Geliştirilmiş donut chart
struct GelistirilmisDonutChart: View {
    let veriler: [KategoriHarcamasi]
    let animasyonTamamlandi: Bool
    @EnvironmentObject var appSettings: AppSettings
    
    @State private var secilenKategori: KategoriHarcamasi?
    @State private var touchLocation: CGPoint = .zero
    
    private var toplamTutar: Double {
        veriler.reduce(0) { $0 + $1.tutar }
    }
    
    var body: some View {
        VStack {
            Text(LocalizedStringKey("reports.credit_card.spending_by_category"))
                .font(.headline)
                .padding(.bottom)
            
            ZStack {
                // 3D gölge efekti
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.black.opacity(0.2), Color.clear],
                            center: .center,
                            startRadius: 80,
                            endRadius: 120
                        )
                    )
                    .frame(width: 240, height: 240)
                    .offset(y: 10)
                    .blur(radius: 10)
                
                // Ana chart
                PieChart(
                    data: veriler,
                    selectedCategory: $secilenKategori,
                    animationComplete: animasyonTamamlandi
                )
                .frame(width: 220, height: 220)
                
                // Merkez bilgi
                VStack(spacing: 4) {
                    if let secilen = secilenKategori {
                        Text(LocalizedStringKey(secilen.localizationKey ?? secilen.kategori))
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                        
                        Text(formatCurrency(
                            amount: secilen.tutar,
                            currencyCode: appSettings.currencyCode,
                            localeIdentifier: appSettings.languageCode
                        ))
                        .font(.headline.bold())
                        
                        Text("\(Int((secilen.tutar / toplamTutar) * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text(LocalizedStringKey("common.total"))
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                        
                        Text(formatCurrency(
                            amount: toplamTutar,
                            currencyCode: appSettings.currencyCode,
                            localeIdentifier: appSettings.languageCode
                        ))
                        .font(.title3.bold())
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: secilenKategori)
            }
            
            // Kategori listesi
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(veriler) { kategori in
                        KategoriChip(
                            kategori: kategori,
                            isSelected: secilenKategori?.id == kategori.id,
                            toplam: toplamTutar
                        )
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3)) {
                                secilenKategori = secilenKategori?.id == kategori.id ? nil : kategori
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.top)
        }
    }
}

// Pie chart şekli
struct PieChart: View {
    let data: [KategoriHarcamasi]
    @Binding var selectedCategory: KategoriHarcamasi?
    let animationComplete: Bool
    
    @State private var startAngles: [Double] = []
    @State private var endAngles: [Double] = []
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(Array(data.enumerated()), id: \.element.id) { index, item in
                    PieSlice(
                        startAngle: .degrees(animationComplete ? startAngles[safe: index] ?? 0 : 0),
                        endAngle: .degrees(animationComplete ? endAngles[safe: index] ?? 0 : 0),
                        color: item.renk,
                        isSelected: selectedCategory?.id == item.id
                    )
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3)) {
                            selectedCategory = selectedCategory?.id == item.id ? nil : item
                        }
                    }
                }
            }
            .onAppear {
                calculateAngles()
            }
        }
    }
    
    private func calculateAngles() {
        let total = data.reduce(0) { $0 + $1.tutar }
        var currentAngle: Double = -90 // Üstten başla
        
        startAngles = []
        endAngles = []
        
        for item in data {
            let percentage = item.tutar / total
            let angle = percentage * 360
            
            startAngles.append(currentAngle)
            endAngles.append(currentAngle + angle)
            
            currentAngle += angle
        }
    }
}

// Pie dilimi
struct PieSlice: Shape {
    var startAngle: Angle
    var endAngle: Angle
    let color: Color
    let isSelected: Bool
    
    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(startAngle.degrees, endAngle.degrees) }
        set {
            startAngle = .degrees(newValue.first)
            endAngle = .degrees(newValue.second)
        }
    }
    
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let innerRadius = radius * 0.6
        
        var path = Path()
        
        // Dış yay
        path.addArc(
            center: center,
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )
        
        // İç yaya bağlan
        path.addLine(to: CGPoint(
            x: center.x + innerRadius * cos(endAngle.radians),
            y: center.y + innerRadius * sin(endAngle.radians)
        ))
        
        // İç yay
        path.addArc(
            center: center,
            radius: innerRadius,
            startAngle: endAngle,
            endAngle: startAngle,
            clockwise: true
        )
        
        path.closeSubpath()
        
        return path
    }
}

// Kategori chip
struct KategoriChip: View {
    let kategori: KategoriHarcamasi
    let isSelected: Bool
    let toplam: Double
    @EnvironmentObject var appSettings: AppSettings
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Circle()
                    .fill(kategori.renk)
                    .frame(width: 12, height: 12)
                
                Text(LocalizedStringKey(kategori.localizationKey ?? kategori.kategori))
                    .font(.caption.bold())
                    .foregroundColor(isSelected ? .white : .primary)
            }
            
            Text("\(Int((kategori.tutar / toplam) * 100))%")
                .font(.caption2)
                .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            isSelected ? kategori.renk : Color(.tertiarySystemGroupedBackground)
        )
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(kategori.renk.opacity(0.3), lineWidth: isSelected ? 0 : 1)
        )
        .scaleEffect(isSelected ? 1.1 : 1.0)
        .animation(.spring(response: 0.3), value: isSelected)
    }
}

// Kategori radar etiketi
struct KategoriRadarEtiketi: View {
    let kategori: Kategori
    let angle: Double
    let radius: CGFloat
    let center: CGPoint
    let isSelected: Bool
    
    var body: some View {
        Image(systemName: kategori.ikonAdi)
            .font(.system(size: isSelected ? 20 : 16))
            .foregroundColor(isSelected ? kategori.renk : .secondary)
            .frame(width: 30, height: 30)
            .background(
                Circle()
                    .fill(isSelected ? kategori.renk.opacity(0.2) : Color.clear)
            )
            .scaleEffect(isSelected ? 1.2 : 1.0)
            .position(
                x: center.x + radius * cos(angle * .pi / 180),
                y: center.y + radius * sin(angle * .pi / 180)
            )
            .animation(.spring(response: 0.3), value: isSelected)
    }
}

// Kart tahmin kartı
struct KartTahminKarti: View {
    let kartID: UUID
    let tahmin: LimitTahmini
    let isExpanded: Bool
    let animasyonTamamlandi: Bool
    @EnvironmentObject var appSettings: AppSettings
    
    // Not: Gerçek uygulamada kart bilgisini ID üzerinden çekmeniz gerekir
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Kart Adı") // Gerçek uygulamada kart adını gösterin
                        .font(.headline)
                    
                    Label(LocalizedStringKey(tahmin.riskSeviyesi.mesajKey), systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(tahmin.riskSeviyesi.renk)
                }
                
                Spacer()
                
                Text("\(Int(tahmin.tahminEdileAysonuKullanim * 100))%")
                    .font(.title2.bold())
                    .foregroundColor(tahmin.riskSeviyesi.renk)
            }
            
            if isExpanded {
                VStack(spacing: 12) {
                    Divider()
                    
                    // Mini ilerleme çubuğu
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 8)
                            
                            Capsule()
                                .fill(tahmin.riskSeviyesi.renk)
                                .frame(
                                    width: geometry.size.width * min(tahmin.tahminEdileAysonuKullanim, 1.0),
                                    height: 8
                                )
                        }
                    }
                    .frame(height: 8)
                    
                    // Önerilen limit
                    HStack {
                        Text(LocalizedStringKey("reports.credit_card.suggested_daily"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(formatCurrency(
                            amount: tahmin.onerilenGunlukLimit,
                            currencyCode: appSettings.currencyCode,
                            localeIdentifier: appSettings.languageCode
                        ))
                        .font(.caption.bold())
                        .foregroundColor(.green)
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .scaleEffect(isExpanded ? 1.02 : 1.0)
        .animation(.spring(response: 0.3), value: isExpanded)
    }
}

// Array safe subscript extension
extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}