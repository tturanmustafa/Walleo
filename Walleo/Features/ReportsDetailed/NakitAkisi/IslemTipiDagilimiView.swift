// Walleo/Features/ReportsDetailed/NakitAkisi/Views/IslemTipiDagilimiView.swift

import SwiftUI
import Charts

struct IslemTipiDagilimiView: View {
    let dagilim: IslemTipiDagilimi
    @EnvironmentObject var appSettings: AppSettings
    
    // İnteraktif seçimi yönetmek için state'ler
    @State private var rawSelectedValue: Double?
    @State private var secilenVeri: (tipLocalized: String, deger: Double)?
    
    // Bilgi etiketinin konumunu (sağ/sol) yönetmek için
    @State private var etiketKonumu: Edge = .leading
    
    private var chartData: [(tipKey: String, tipLocalized: String, gelir: Double, gider: Double, net: Double, renk: Color)] {
        let languageBundle = Bundle.getLanguageBundle(for: appSettings.languageCode)
        let normalLabel = languageBundle.localizedString(forKey: "cashflow.normal_transactions", value: "", table: nil)
        let taksitliLabel = languageBundle.localizedString(forKey: "cashflow.installment_transactions", value: "", table: nil)
        let tekrarliLabel = languageBundle.localizedString(forKey: "cashflow.recurring_transactions", value: "", table: nil)
        
        return [
            ("cashflow.normal_transactions", normalLabel, dagilim.normalIslemler.toplamGelir, dagilim.normalIslemler.toplamGider, dagilim.normalIslemler.netEtki, .blue),
            ("cashflow.installment_transactions", taksitliLabel, dagilim.taksitliIslemler.toplamGelir, dagilim.taksitliIslemler.toplamGider, dagilim.taksitliIslemler.netEtki, .orange),
            ("cashflow.recurring_transactions", tekrarliLabel, dagilim.tekrarliIslemler.toplamGelir, dagilim.tekrarliIslemler.toplamGider, dagilim.tekrarliIslemler.netEtki, .purple)
        ]
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("cashflow.transaction_type_distribution")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Chart {
                ForEach(chartData, id: \.tipKey) { veri in
                    BarMark(x: .value("Tip", veri.tipLocalized), y: .value("Gelir", veri.gelir))
                        .foregroundStyle(.green).cornerRadius(4)
                    
                    BarMark(x: .value("Tip", veri.tipLocalized), y: .value("Gider", -veri.gider))
                        .foregroundStyle(veri.renk).cornerRadius(4)
                }
            }
            .frame(height: 200)
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let doubleValue = value.as(Double.self) {
                            Text(formatCompactCurrency(amount: doubleValue)).font(.caption2)
                        }
                    }
                }
            }
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    // --- DÜZELTME: 'guard let' yerine 'if let' kullanılıyor ---
                    // Bu, ViewBuilder hatasını çözer.
                    if let plotFrameAnchor = proxy.plotFrame {
                        let plotFrame = geometry[plotFrameAnchor]
                        
                        Rectangle().fill(.clear).contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        let location = value.location
                                        if location.x < plotFrame.midX {
                                            etiketKonumu = .trailing
                                        } else {
                                            etiketKonumu = .leading
                                        }
                                        
                                        if let (tip, yDegeri) = proxy.value(at: location, as: (String, Double).self) {
                                            rawSelectedValue = yDegeri
                                            if let barVerisi = chartData.first(where: { $0.tipLocalized == tip }) {
                                                secilenVeri = (tipLocalized: tip, deger: yDegeri >= 0 ? barVerisi.gelir : -barVerisi.gider)
                                            }
                                        }
                                    }
                                    .onEnded { _ in
                                        rawSelectedValue = nil
                                        secilenVeri = nil
                                    }
                            )
                        
                        if let rawSelectedValue, let secilenVeri {
                            let isGelir = rawSelectedValue >= 0
                            let yPosition = proxy.position(forY: rawSelectedValue) ?? 0
                            
                            Path { path in
                                path.move(to: CGPoint(x: plotFrame.minX, y: yPosition))
                                path.addLine(to: CGPoint(x: plotFrame.maxX, y: yPosition))
                            }
                            .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                            .foregroundColor(.gray.opacity(0.8))
                            
                            let etiketGenisligi: CGFloat = 130
                            let etiketXKonumu: CGFloat = {
                                if etiketKonumu == .leading {
                                    return plotFrame.minX + etiketGenisligi / 2 + 5
                                } else {
                                    return plotFrame.maxX - etiketGenisligi / 2 - 5
                                }
                            }()
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(secilenVeri.tipLocalized)
                                    .font(.caption).fontWeight(.bold)
                                    .foregroundColor(.secondary)
                                Text(formatCurrency(amount: secilenVeri.deger, currencyCode: appSettings.currencyCode, localeIdentifier: appSettings.languageCode))
                                    .font(.headline.bold())
                                    .foregroundColor(isGelir ? .green : .red)
                            }
                            .frame(width: etiketGenisligi, alignment: etiketKonumu == .leading ? .leading : .trailing)
                            .padding(8)
                            .background(Color(.systemBackground).opacity(0.8))
                            .cornerRadius(8)
                            .shadow(color: .black.opacity(0.1), radius: 5)
                            .position(x: etiketXKonumu, y: yPosition)
                        }
                    }
                }
            }
            
            // Alttaki detay kartları
            VStack(spacing: 12) {
                islemTipiKarti(baslik: "cashflow.normal_transactions", ikon: "arrow.right.circle.fill", ozet: dagilim.normalIslemler, renk: .blue)
                islemTipiKarti(baslik: "cashflow.installment_transactions", ikon: "creditcard.viewfinder", ozet: dagilim.taksitliIslemler, renk: .orange)
                islemTipiKarti(baslik: "cashflow.recurring_transactions", ikon: "arrow.clockwise.circle.fill", ozet: dagilim.tekrarliIslemler, renk: .purple)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
    
    // Yardımcı View: Detay kartı (Değişiklik yok)
    @ViewBuilder
    private func islemTipiKarti(baslik: String, ikon: String, ozet: IslemTipiDagilimi.IslemTipiOzet, renk: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: ikon)
                .font(.title2)
                .foregroundColor(renk)
                .frame(width: 40, height: 40)
                .background(renk.opacity(0.15))
                .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(LocalizedStringKey(baslik))
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text(String(format: "%.1f%%", ozet.yuzdePayi))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.gray.opacity(0.15))
                        .cornerRadius(4)
                }
                
                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up")
                            .font(.caption2)
                            .foregroundColor(.green)
                        Text(formatCurrency(amount: ozet.toplamGelir, currencyCode: appSettings.currencyCode, localeIdentifier: appSettings.languageCode))
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down")
                            .font(.caption2)
                            .foregroundColor(.red)
                        Text(formatCurrency(amount: ozet.toplamGider, currencyCode: appSettings.currencyCode, localeIdentifier: appSettings.languageCode))
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    
                    Spacer()
                    
                    Text(formatCurrency(amount: ozet.netEtki, currencyCode: appSettings.currencyCode, localeIdentifier: appSettings.languageCode))
                        .font(.caption.bold())
                        .foregroundColor(ozet.netEtki >= 0 ? .green : .red)
                }
            }
        }
        .padding()
        .background(Color(.tertiarySystemGroupedBackground))
        .cornerRadius(12)
    }
    
    // Yardımcı Fonksiyon: Sayıları kısaltmak için (Değişiklik yok)
    private func formatCompactCurrency(amount: Double) -> String {
        let absAmount = abs(amount)
        let sign = amount < 0 ? "-" : ""
        
        if absAmount >= 1_000_000 {
            return "\(sign)\(String(format: "%.1fM", absAmount / 1_000_000))"
        } else if absAmount >= 1_000 {
            return "\(sign)\(String(format: "%.1fK", absAmount / 1_000))"
        } else {
            return "\(sign)\(Int(absAmount))"
        }
    }
}
