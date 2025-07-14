//
//  InteractiveLineChartView.swift
//  Walleo
//
//  Created by Mustafa Turan on 14.07.2025.
//


// >> YENİ DOSYA: Features/Reports/Views/InteractiveLineChartView.swift

import SwiftUI
import Charts

struct InteractiveLineChartView: View {
    let data: [GunlukHarcama]
    let renk: Color

    @State private var secilenTarih: Date?
    
    // Grafik üzerindeki "lolipop" işaretçisinin verisini tutan değişken
    private var secilenVeri: GunlukHarcama? {
        if let secilenTarih {
            return data.first {
                Calendar.current.isDate($0.gun, inSameDayAs: secilenTarih)
            }
        }
        return nil
    }

    var body: some View {
        Chart {
            // Arka planda tüm veriler için görünmez bir alan çiziyoruz.
            // Bu, kullanıcının boş alanlara dokunduğunda bile en yakın noktayı bulmamızı sağlar.
            ForEach(data) { gunlukHarcama in
                AreaMark(
                    x: .value("Gün", gunlukHarcama.gun, unit: .day),
                    y: .value("Tutar", gunlukHarcama.tutar)
                )
                .foregroundStyle(renk.opacity(0.1))
            }
            
            // Asıl harcama çizgisini çiziyoruz.
            ForEach(data) { gunlukHarcama in
                LineMark(
                    x: .value("Gün", gunlukHarcama.gun, unit: .day),
                    y: .value("Tutar", gunlukHarcama.tutar)
                )
                .foregroundStyle(renk)
                .symbol(by: .value("Tutar", gunlukHarcama.tutar))
                .interpolationMethod(.catmullRom) // Çizgiyi yumuşatıyoruz.
            }

            // Kullanıcı bir nokta seçtiğinde dikey bir çizgi (RuleMark) gösteriyoruz.
            if let secilenVeri {
                RuleMark(x: .value("Seçilen Gün", secilenVeri.gun))
                    .foregroundStyle(Color.gray.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                    .annotation(position: .top, alignment: .center) {
                        // Çizginin üstünde, seçilen günün verisini gösteren "lolipop"
                        VStack(spacing: 4) {
                            Text(secilenVeri.gun, format: .dateTime.day().month())
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(formatCurrency(amount: secilenVeri.tutar, currencyCode: "TRY", localeIdentifier: "tr_TR"))
                                .font(.headline.bold())
                        }
                        .padding(8)
                        .background(Color(.systemBackground))
                        .cornerRadius(8)
                        .shadow(radius: 3)
                    }
            }
        }
        .frame(height: 250)
        // Grafik üzerinde gezinme hareketini ve seçilen tarihi güncellemeyi yöneten bölüm
        .chartXSelection(value: $secilenTarih)
    }
}