//
//  HarcamaAliskanliklariRaporView.swift
//  Walleo
//
//  Created by Mustafa Turan on 14.07.2025.
//


import SwiftUI
import Charts

struct HarcamaAliskanliklariRaporView: View {
    @EnvironmentObject var appSettings: AppSettings
    let veri: HarcamaAliskanligiRaporVerisi
    
    @State private var secilenHucre: (gun: String, saat: Int)?
    @State private var hucreDetayGoster = false
    @State private var harcamaBuyukluguFiltresi: HarcamaBuyuklugu = .tumu
    @State private var animasyonTamamlandi = false
    
    enum HarcamaBuyuklugu: String, CaseIterable {
        case tumu = "detailed_reports.spending_habits.all_sizes"
        case kucuk = "detailed_reports.spending_habits.small"
        case orta = "detailed_reports.spending_habits.medium"
        case buyuk = "detailed_reports.spending_habits.large"
        
        var aralik: ClosedRange<Double>? {
            switch self {
            case .tumu: return nil
            case .kucuk: return 0...100
            case .orta: return 100...500
            case .buyuk: return 500...Double.infinity
            }
        }
    }
    
    private var filtrelenmisVeri: HarcamaAliskanligiRaporVerisi {
        guard let aralik = harcamaBuyukluguFiltresi.aralik else { return veri }
        
        // Filtreleme mantığı burada uygulanacak
        // Şimdilik orijinal veriyi dönüyoruz
        return veri
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Filtre Seçici
                filtreSecici
                
                // Zaman Isı Haritası
                zamanHaritasi
                    .padding(.horizontal)
                
                // Ödeme Tipi Dağılımı
                odemeTipiDagilimi
                    .padding(.horizontal)
                
                // İstatistik Kartları
                istatistikKartlari
                    .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .sheet(isPresented: $hucreDetayGoster) {
            if let hucre = secilenHucre {
                HucreDetaySheet(gun: hucre.gun, saat: hucre.saat, veri: filtrelenmisVeri)
                    .environmentObject(appSettings)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8)) {
                animasyonTamamlandi = true
            }
        }
    }
    
    // MARK: - Filtre Seçici
    private var filtreSecici: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(HarcamaBuyuklugu.allCases, id: \.self) { buyukluk in
                    FilterChip(
                        title: LocalizedStringKey(buyukluk.rawValue),
                        isSelected: harcamaBuyukluguFiltresi == buyukluk
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            harcamaBuyukluguFiltresi = buyukluk
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Zaman Isı Haritası
    private var zamanHaritasi: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("detailed_reports.spending_habits.time_heatmap")
                .font(.headline)
                .foregroundColor(.secondary)
            
            VStack(spacing: 2) {
                // Saat başlıkları
                HStack(spacing: 2) {
                    Text("")
                        .frame(width: 60)
                    
                    ForEach(0..<24) { saat in
                        Text("\(saat)")
                            .font(.caption2)
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Gün satırları
                ForEach(gunSirasi(), id: \.self) { gun in
                    HStack(spacing: 2) {
                        Text(LocalizedStringKey("day.\(gun.lowercased())"))
                            .font(.caption)
                            .frame(width: 60, alignment: .leading)
                            .foregroundColor(.secondary)
                        
                        ForEach(0..<24) { saat in
                            let yogunluk = getYogunluk(gun: gun, saat: saat)
                            
                            Rectangle()
                                .fill(heatMapColor(yogunluk: yogunluk))
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .aspectRatio(1, contentMode: .fit)
                                .cornerRadius(2)
                                .opacity(animasyonTamamlandi ? 1 : 0)
                                .scaleEffect(animasyonTamamlandi ? 1 : 0.8)
                                .animation(
                                    .spring(response: 0.5, dampingFraction: 0.8)
                                    .delay(Double(saat) * 0.01 + Double(gunSirasi().firstIndex(of: gun) ?? 0) * 0.05),
                                    value: animasyonTamamlandi
                                )
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        secilenHucre = (gun, saat)
                                        hucreDetayGoster = true
                                    }
                                    
                                    // Haptic feedback
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                    impactFeedback.impactOccurred()
                                }
                        }
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            
            // Renk skalası
            HStack {
                Text("detailed_reports.spending_habits.low")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 4) {
                    ForEach(0..<5) { i in
                        Rectangle()
                            .fill(heatMapColor(yogunluk: Double(i) / 4.0))
                            .frame(width: 20, height: 10)
                            .cornerRadius(2)
                    }
                }
                
                Text("detailed_reports.spending_habits.high")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }
    
    // MARK: - Ödeme Tipi Dağılımı
    private var odemeTipiDagilimi: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("detailed_reports.spending_habits.payment_type")
                .font(.headline)
                .foregroundColor(.secondary)
            
            VStack(spacing: 16) {
                ForEach(veri.odemeTipiDagilimi.sorted(by: { $0.value > $1.value }), id: \.key) { tip, tutar in
                    let yuzde = veri.toplamHarcama > 0 ? (tutar / veri.toplamHarcama) : 0
                    
                    VStack(spacing: 8) {
                        HStack {
                            Label(
                                LocalizedStringKey("payment_type.\(tip.lowercased())"),
                                systemImage: tip == "Nakit" ? "banknote" : "creditcard"
                            )
                            .font(.subheadline)
                            
                            Spacer()
                            
                            Text(formatCurrency(
                                amount: tutar,
                                currencyCode: appSettings.currencyCode,
                                localeIdentifier: appSettings.languageCode
                            ))
                            .font(.subheadline.bold())
                        }
                        
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .fill(Color(.systemGray5))
                                    .frame(height: 8)
                                    .cornerRadius(4)
                                
                                Rectangle()
                                    .fill(tip == "Nakit" ? Color.green : Color.blue)
                                    .frame(width: animasyonTamamlandi ? geometry.size.width * yuzde : 0, height: 8)
                                    .cornerRadius(4)
                                    .animation(.spring(response: 0.8, dampingFraction: 0.8), value: animasyonTamamlandi)
                            }
                        }
                        .frame(height: 8)
                        
                        HStack {
                            Text("\(Int(yuzde * 100))%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                        }
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
    }
    
    // MARK: - İstatistik Kartları
    private var istatistikKartlari: some View {
        VStack(spacing: 16) {
            // Ortalama Harcama
            StatCard(
                title: "detailed_reports.spending_habits.avg_transaction",
                value: formatCurrency(
                    amount: veri.ortalamaHarcama,
                    currencyCode: appSettings.currencyCode,
                    localeIdentifier: appSettings.languageCode
                ),
                icon: "chart.bar",
                color: .purple
            )
            
            // En Yoğun Gün
            StatCard(
                title: "detailed_reports.spending_habits.busiest_day",
                value: LocalizedStringKey("day.\(veri.enYogunGun.lowercased())"),
                subtitle: "\(veri.enYogunGunIslemSayisi) \(Text("detailed_reports.spending_habits.transactions"))",
                icon: "calendar",
                color: .orange
            )
            
            // En Yoğun Saat
            StatCard(
                title: "detailed_reports.spending_habits.busiest_hour",
                value: String(format: "%02d:00 - %02d:00", veri.enYogunSaat, (veri.enYogunSaat + 1) % 24),
                subtitle: "\(veri.enYogunSaatIslemSayisi) \(Text("detailed_reports.spending_habits.transactions"))",
                icon: "clock",
                color: .indigo
            )
        }
    }
    
    // MARK: - Helper Functions
    private func gunSirasi() -> [String] {
        ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
    }
    
    private func getYogunluk(gun: String, saat: Int) -> Double {
        let gunlukVeri = veri.gunlukDagilim[gun] ?? [:]
        let saatlikTutar = gunlukVeri[saat] ?? 0
        let maxTutar = veri.gunlukDagilim.values.flatMap { $0.values }.max() ?? 1
        return saatlikTutar / maxTutar
    }
    
    private func heatMapColor(yogunluk: Double) -> Color {
        if yogunluk == 0 { return Color(.systemGray6) }
        
        let opacity = 0.2 + (yogunluk * 0.8)
        return Color.red.opacity(opacity)
    }
}

// MARK: - Alt Bileşenler

struct FilterChip: View {
    let title: LocalizedStringKey
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.accentColor : Color(.systemGray5))
                )
        }
    }
}

struct StatCard: View {
    let title: LocalizedStringKey
    let value: LocalizedStringKey
    var subtitle: LocalizedStringKey? = nil
    let icon: String
    let color: Color
    
    init(title: LocalizedStringKey, value: String, subtitle: LocalizedStringKey? = nil, icon: String, color: Color) {
        self.title = title
        self.value = LocalizedStringKey(value)
        self.subtitle = subtitle
        self.icon = icon
        self.color = color
    }
    
    init(title: LocalizedStringKey, value: LocalizedStringKey, subtitle: LocalizedStringKey? = nil, icon: String, color: Color) {
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.icon = icon
        self.color = color
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.title3.bold())
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 50, height: 50)
                .background(color.opacity(0.1))
                .cornerRadius(12)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }
}

struct HucreDetaySheet: View {
    let gun: String
    let saat: Int
    let veri: HarcamaAliskanligiRaporVerisi
    @EnvironmentObject var appSettings: AppSettings
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                // Başlık
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "clock.fill")
                            .font(.title2)
                            .foregroundColor(.orange)
                        
                        Text("\(String(format: "%02d:00 - %02d:00", saat, (saat + 1) % 24))")
                            .font(.title2.bold())
                    }
                    
                    Text(LocalizedStringKey("day.\(gun.lowercased())"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                
                // İstatistikler
                HStack(spacing: 20) {
                    VStack {
                        Text("detailed_reports.spending_habits.total_spent")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(formatCurrency(
                            amount: veri.gunlukDagilim[gun]?[saat] ?? 0,
                            currencyCode: appSettings.currencyCode,
                            localeIdentifier: appSettings.languageCode
                        ))
                        .font(.title3.bold())
                        .foregroundColor(.red)
                    }
                    
                    Divider()
                        .frame(height: 40)
                    
                    VStack {
                        Text("detailed_reports.spending_habits.transaction_count")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        // TODO: İşlem sayısını hesapla
                        Text("--")
                            .font(.title3.bold())
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                .padding(.horizontal)
                
                // İşlem listesi placeholder
                Spacer()
                
                VStack {
                    Image(systemName: "list.bullet")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    
                    Text("detailed_reports.spending_habits.transactions_placeholder")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding()
                }
                .frame(maxWidth: .infinity)
                
                Spacer()
            }
            .navigationTitle("detailed_reports.spending_habits.time_detail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("common.done") { dismiss() }
                }
            }
        }
    }
}