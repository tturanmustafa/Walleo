//
//  GelirAnaliziRaporView.swift
//  Walleo
//
//  Created by Mustafa Turan on 14.07.2025.
//


// Dosya: /Users/mt/Documents/GitHub/Walleo/Walleo/Features/ReportDetailed/GelirAnaliziRaporView.swift

import SwiftUI
import Charts

struct GelirAnaliziRaporView: View {
    @EnvironmentObject var appSettings: AppSettings
    let veri: GelirAnaliziVerisi
    
    @State private var secilenKategori: Kategori?
    @State private var animasyonTamamlandi = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Başlık
                baslikView
                
                // Gelir Kaynakları Grafiği
                gelirKaynaklariGrafigi
                
                // Gelir Takvimi
                gelirTakvimi
                
                // İstatistik Kartları
                istatistikKartlari
                
                // En Verimli Gün Kartı
                if let enVerimliGun = veri.enYuksekGelirGunu {
                    enVerimliGunKarti(gun: enVerimliGun)
                }
            }
            .padding()
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                animasyonTamamlandi = true
            }
        }
    }
    
    private var baslikView: some View {
        HStack {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.title2)
                .foregroundColor(.green)
            
            Text("detailed_reports.income_analysis.title")
                .font(.title2.bold())
            
            Spacer()
        }
        .padding(.bottom, 10)
    }
    
    private var gelirKaynaklariGrafigi: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("detailed_reports.income_analysis.sources_chart_title")
                .font(.headline)
            
            Chart(veri.kategoriDagilimi) { item in
                SectorMark(
                    angle: .value("Tutar", item.tutar),
                    innerRadius: .ratio(0.618),
                    angularInset: 2
                )
                .foregroundStyle(item.kategori.renk)
                .cornerRadius(8)
                .opacity(secilenKategori == nil || secilenKategori?.id == item.kategori.id ? 1 : 0.3)
            }
            .frame(height: 250)
            .chartBackground { _ in
                VStack {
                    Text("detailed_reports.income_analysis.total_income")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(formatCurrency(
                        amount: veri.toplamGelir,
                        currencyCode: appSettings.currencyCode,
                        localeIdentifier: appSettings.languageCode
                    ))
                    .font(.title2.bold())
                    .foregroundColor(.green)
                }
            }
            .chartAngleSelection(value: .constant(nil))
            .sensoryFeedback(.selection, trigger: secilenKategori)
            
            // Kategori Listesi
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 12) {
                ForEach(veri.kategoriDagilimi) { item in
                    kategoriKarti(item: item)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func kategoriKarti(item: KategoriDagilimItem) -> some View {
        Button {
            withAnimation(.spring(response: 0.3)) {
                secilenKategori = secilenKategori?.id == item.kategori.id ? nil : item.kategori
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: item.kategori.ikonAdi)
                    .font(.title3)
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(item.kategori.renk)
                    .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(LocalizedStringKey(item.kategori.localizationKey ?? item.kategori.isim))
                        .font(.caption.bold())
                    
                    Text(formatCurrency(
                        amount: item.tutar,
                        currencyCode: appSettings.currencyCode,
                        localeIdentifier: appSettings.languageCode
                    ))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    
                    Text("\(Int(item.yuzde))%")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(secilenKategori?.id == item.kategori.id ? 
                          item.kategori.renk.opacity(0.2) : Color(.systemGray5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(secilenKategori?.id == item.kategori.id ? 
                           item.kategori.renk : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
    
    private var gelirTakvimi: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("detailed_reports.income_analysis.income_calendar_title")
                .font(.headline)
            
            let takvimGunleri = takvimiOlustur()
            let sutunlar = Array(repeating: GridItem(.flexible()), count: 7)
            
            LazyVGrid(columns: sutunlar, spacing: 8) {
                // Gün başlıkları
                ForEach(gunBasliklari(), id: \.self) { gun in
                    Text(gun)
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                }
                
                // Takvim günleri
                ForEach(takvimGunleri) { gun in
                    takvimGunuView(gun: gun)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func takvimGunuView(gun: TakvimGunu) -> some View {
        let gelir = veri.gunlukGelirler[gun.tarih] ?? 0
        let maxGelir = veri.gunlukGelirler.values.max() ?? 1
        let yogunluk = gelir / maxGelir
        
        return VStack(spacing: 4) {
            Text("\(Calendar.current.component(.day, from: gun.tarih))")
                .font(.caption2.bold())
                .foregroundColor(gun.ayIcinde ? .primary : .secondary)
            
            if gelir > 0 {
                Circle()
                    .fill(Color.green.opacity(0.3 + (yogunluk * 0.7)))
                    .frame(width: 20, height: 20)
                    .overlay(
                        Text("+")
                            .font(.caption2.bold())
                            .foregroundColor(.green)
                    )
            }
        }
        .frame(height: 50)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(gun.ayIcinde ? Color(.systemBackground) : Color(.systemGray5))
        )
        .opacity(animasyonTamamlandi ? 1 : 0)
        .scaleEffect(animasyonTamamlandi ? 1 : 0.8)
        .animation(.spring(response: 0.5).delay(Double(gun.id) * 0.01), value: animasyonTamamlandi)
    }
    
    private var istatistikKartlari: some View {
        HStack(spacing: 12) {
            // En Yüksek Gelir
            istatistikKarti(
                baslik: "detailed_reports.income_analysis.highest_income",
                deger: formatCurrency(
                    amount: veri.enYuksekGelir,
                    currencyCode: appSettings.currencyCode,
                    localeIdentifier: appSettings.languageCode
                ),
                renk: .green,
                ikon: "arrow.up.circle.fill"
            )
            
            // Ortalama Gelir
            istatistikKarti(
                baslik: "detailed_reports.income_analysis.average_income",
                deger: formatCurrency(
                    amount: veri.ortalamaGelir,
                    currencyCode: appSettings.currencyCode,
                    localeIdentifier: appSettings.languageCode
                ),
                renk: .blue,
                ikon: "equal.circle.fill"
            )
            
            // En Düşük Gelir
            istatistikKarti(
                baslik: "detailed_reports.income_analysis.lowest_income",
                deger: formatCurrency(
                    amount: veri.enDusukGelir,
                    currencyCode: appSettings.currencyCode,
                    localeIdentifier: appSettings.languageCode
                ),
                renk: .orange,
                ikon: "arrow.down.circle.fill"
            )
        }
    }
    
    private func istatistikKarti(baslik: LocalizedStringKey, deger: String, renk: Color, ikon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: ikon)
                .font(.title2)
                .foregroundColor(renk)
            
            Text(baslik)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(deger)
                .font(.callout.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func enVerimliGunKarti(gun: (tarih: Date, tutar: Double)) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "star.circle.fill")
                        .font(.title)
                        .foregroundColor(.yellow)
                    
                    Text("detailed_reports.income_analysis.most_productive_day")
                        .font(.headline)
                }
                
                Text(gun.tarih.formatted(date: .complete, time: .omitted))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(formatCurrency(
                    amount: gun.tutar,
                    currencyCode: appSettings.currencyCode,
                    localeIdentifier: appSettings.languageCode
                ))
                .font(.title2.bold())
                .foregroundColor(.green)
            }
            
            Spacer()
            
            Image(systemName: "sparkles")
                .font(.system(size: 40))
                .foregroundColor(.yellow.opacity(0.3))
                .rotationEffect(.degrees(animasyonTamamlandi ? 360 : 0))
                .animation(.linear(duration: 20).repeatForever(autoreverses: false), value: animasyonTamamlandi)
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color.yellow.opacity(0.1), Color.green.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.yellow.opacity(0.5), lineWidth: 1)
        )
    }
    
    // Yardımcı fonksiyonlar
    private func takvimiOlustur() -> [TakvimGunu] {
        // Takvim mantığı (NakitAkisiRaporView'dakine benzer)
        var gunler: [TakvimGunu] = []
        let calendar = Calendar.current
        
        // veri.gunlukGelirler'den ilk ve son tarihi bul
        guard let ilkTarih = veri.gunlukGelirler.keys.min(),
              let sonTarih = veri.gunlukGelirler.keys.max() else { return [] }
        
        // İlk tarihin bulunduğu ayın başını bul
        guard let ayBasi = calendar.dateInterval(of: .month, for: ilkTarih)?.start,
              let ilkGun = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: ayBasi)) else { return [] }
        
        // 42 gün oluştur (6 hafta)
        for i in 0..<42 {
            if let gun = calendar.date(byAdding: .day, value: i, to: ilkGun) {
                let ayIcinde = calendar.isDate(gun, equalTo: ilkTarih, toGranularity: .month)
                gunler.append(TakvimGunu(id: i, tarih: gun, ayIcinde: ayIcinde))
            }
        }
        
        return gunler
    }
    
    private func gunBasliklari() -> [String] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: appSettings.languageCode)
        var gunler = formatter.shortWeekdaySymbols!
        // Pazartesi'yi başa al
        let pazar = gunler.removeFirst()
        gunler.append(pazar)
        return gunler
    }
}

// Takvim için veri modeli
private struct TakvimGunu: Identifiable {
    let id: Int
    let tarih: Date
    let ayIcinde: Bool
}