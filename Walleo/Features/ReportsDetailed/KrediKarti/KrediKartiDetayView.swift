//
//  KrediKartiDetayView.swift
//  Walleo
//
//  Created by Mustafa Turan on 15.07.2025.
//


// >> YENİ DOSYA: Features/ReportsDetailed/Views/KrediKartiDetayView.swift

import SwiftUI
import Charts

struct KrediKartiDetayView: View {
    let kartRaporlari: [KartDetayRaporu]
    @Binding var secilenKartID: UUID?
    @EnvironmentObject var appSettings: AppSettings
    
    @State private var secilenGrafik: GrafikTuru = .gunluk
    @State private var animasyonTamamlandi = false
    
    enum GrafikTuru: String, CaseIterable {
        case gunluk = "reports.credit_card.daily_trend"
        case kategori = "reports.credit_card.category_distribution"
        case haftalik = "reports.credit_card.weekly_heatmap"
    }
    
    private var secilenKart: KartDetayRaporu? {
        kartRaporlari.first { $0.id == secilenKartID } ?? kartRaporlari.first
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Kart Seçici
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(kartRaporlari) { rapor in
                            KartSeciciChip(
                                hesap: rapor.hesap,
                                isSelected: secilenKartID == rapor.id
                            )
                            .onTapGesture {
                                withAnimation(.spring(response: 0.3)) {
                                    secilenKartID = rapor.id
                                    animasyonTamamlandi = false
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        animasyonTamamlandi = true
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                if let kart = secilenKart {
                    // Grafik Türü Seçici
                    Picker("Grafik Türü", selection: $secilenGrafik.animation()) {
                        ForEach(GrafikTuru.allCases, id: \.self) { tur in
                            Text(LocalizedStringKey(tur.rawValue)).tag(tur)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    // Seçilen Grafik
                    Group {
                        switch secilenGrafik {
                        case .gunluk:
                            InteraktifCizgiGrafik(
                                veriler: kart.gunlukHarcamaTrendi,
                                renk: kart.hesap.renk,
                                animasyonTamamlandi: animasyonTamamlandi
                            )
                            .frame(height: 300)
                            .padding()
                            
                        case .kategori:
                            if !kart.kategoriDagilimi.isEmpty {
                                GelistirilmisDonutChart(
                                    veriler: kart.kategoriDagilimi,
                                    animasyonTamamlandi: animasyonTamamlandi
                                )
                                .frame(height: 350)
                                .padding()
                            } else {
                                ContentUnavailableView(
                                    LocalizedStringKey("reports.credit_card.no_category_data"),
                                    systemImage: "chart.pie"
                                )
                                .frame(height: 300)
                            }
                            
                        case .haftalik:
                            HaftalikIsiHaritasi(
                                veriler: kart.haftalikIsiHaritasi,
                                animasyonTamamlandi: animasyonTamamlandi
                            )
                            .padding()
                        }
                    }
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(16)
                    .padding(.horizontal)
                    
                    // Kategori Trend Kartları
                    if !kart.kategoriTrendleri.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(LocalizedStringKey("reports.credit_card.category_trends"))
                                .font(.headline)
                                .padding(.horizontal)
                            
                            ForEach(kart.kategoriTrendleri) { trend in
                                KategoriTrendKarti(trend: trend)
                                    .padding(.horizontal)
                            }
                        }
                    }
                }
            }
            .padding(.vertical)
        }
        .onAppear {
            animasyonTamamlandi = true
        }
    }
}

// İnteraktif Çizgi Grafik
struct InteraktifCizgiGrafik: View {
    let veriler: [GunlukHarcama]
    let renk: Color
    let animasyonTamamlandi: Bool
    @EnvironmentObject var appSettings: AppSettings
    
    @State private var secilenNokta: GunlukHarcama?
    @State private var touchLocation: CGPoint = .zero
    
    var body: some View {
        Chart {
            ForEach(veriler) { veri in
                LineMark(
                    x: .value("Tarih", veri.gun),
                    y: .value("Tutar", animasyonTamamlandi ? veri.tutar : 0)
                )
                .foregroundStyle(renk.gradient)
                .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.catmullRom)
                
                AreaMark(
                    x: .value("Tarih", veri.gun),
                    y: .value("Tutar", animasyonTamamlandi ? veri.tutar : 0)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [renk.opacity(0.3), renk.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                
                if let secilen = secilenNokta, secilen.id == veri.id {
                    PointMark(
                        x: .value("Tarih", veri.gun),
                        y: .value("Tutar", veri.tutar)
                    )
                    .foregroundStyle(renk)
                    .symbolSize(200)
                    .annotation(position: .top) {
                        VStack(spacing: 4) {
                            Text(veri.gun, format: .dateTime.day().month())
                                .font(.caption.bold())
                            Text(formatCurrency(
                                amount: veri.tutar,
                                currencyCode: appSettings.currencyCode,
                                localeIdentifier: appSettings.languageCode
                            ))
                            .font(.headline)
                            Text("\(veri.islemSayisi) \(NSLocalizedString("common.transaction", comment: ""))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(8)
                        .background(Color(.systemBackground))
                        .cornerRadius(8)
                        .shadow(radius: 4)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.day())
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
        .animation(.spring(response: 0.8), value: animasyonTamamlandi)
        .chartBackground { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let location):
                            if let data = findClosestData(at: location, geometry: geometry, proxy: proxy) {
                                secilenNokta = data
                            }
                        case .ended:
                            secilenNokta = nil
                        }
                    }
            }
        }
    }
    
    private func findClosestData(at location: CGPoint, geometry: GeometryProxy, proxy: ChartProxy) -> GunlukHarcama? {
        // En yakın veri noktasını bul
        var closestData: GunlukHarcama?
        var minDistance: CGFloat = .infinity
        
        for veri in veriler {
            guard let plotFrame = proxy.plotAreaFrame else { continue }
            let xPos = proxy.position(forX: veri.gun) ?? 0
            let yPos = proxy.position(forY: veri.tutar) ?? 0
            
            let dataPoint = CGPoint(
                x: xPos + plotFrame.minX,
                y: geometry.size.height - (yPos + plotFrame.minY)
            )
            
            let distance = hypot(location.x - dataPoint.x, location.y - dataPoint.y)
            if distance < minDistance && distance < 50 {
                minDistance = distance
                closestData = veri
            }
        }
        
        return closestData
    }
}
