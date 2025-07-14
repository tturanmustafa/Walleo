//
//  HarcamaTrendiChartView.swift
//  Walleo
//
//  Created by Mustafa Turan on 14.07.2025.
//


import SwiftUI
import Charts

struct HarcamaTrendiChartView: View {
    let gunlukHarcamalar: [KrediKartiRaporViewModel.GunlukHarcama]
    @EnvironmentObject var appSettings: AppSettings
    
    @State private var selectedDate: Date?
    @State private var animateChart = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("credit_card_report.trend.title")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Chart(gunlukHarcamalar) { harcama in
                LineMark(
                    x: .value("Tarih", harcama.tarih),
                    y: .value("Tutar", animateChart ? harcama.toplamTutar : 0)
                )
                .foregroundStyle(
                    .linearGradient(
                        colors: [.blue, .purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.catmullRom)
                
                AreaMark(
                    x: .value("Tarih", harcama.tarih),
                    y: .value("Tutar", animateChart ? harcama.toplamTutar : 0)
                )
                .foregroundStyle(
                    .linearGradient(
                        colors: [.blue.opacity(0.3), .purple.opacity(0.1)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)
                
                if let selected = selectedDate,
                   Calendar.current.isDate(harcama.tarih, inSameDayAs: selected) {
                    RuleMark(x: .value("Seçili", harcama.tarih))
                        .foregroundStyle(.gray.opacity(0.3))
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                        .annotation(position: .top, alignment: .center) {
                            VStack(spacing: 4) {
                                Text(formatCurrency(
                                    amount: harcama.toplamTutar,
                                    currencyCode: appSettings.currencyCode,
                                    localeIdentifier: appSettings.languageCode
                                ))
                                .font(.caption.bold())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .cornerRadius(6)
                                
                                Text(harcama.tarih, format: .dateTime.day().month())
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                }
            }
            .frame(height: 250)
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
                        if let amount = value.as(Double.self) {
                            Text(formatCurrency(
                                amount: amount,
                                currencyCode: appSettings.currencyCode,
                                localeIdentifier: appSettings.languageCode
                            ))
                            .font(.caption)
                        }
                    }
                }
            }
            .chartAngleSelection(value: .constant(nil))
            .chartBackground { chartProxy in
                GeometryReader { geometry in
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .onTapGesture { location in
                            let xPosition = location.x - geometry.frame(in: .local).minX
                            if let date = chartProxy.value(atX: xPosition, as: Date.self) {
                                selectedDate = findClosestDate(to: date)
                            }
                        }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).delay(0.2)) {
                animateChart = true
            }
        }
    }
    
    private func findClosestDate(to date: Date) -> Date? {
        gunlukHarcamalar.min(by: { abs($0.tarih.timeIntervalSince(date)) < abs($1.tarih.timeIntervalSince(date)) })?.tarih
    }
}