//
//  DonutChartView.swift
//  Walleo
//
//  Created by Mustafa Turan on 14.07.2025.
//

import SwiftUI
import Charts

struct DonutChartView: View {
    let data: [KategoriHarcamasi]
    @EnvironmentObject var appSettings: AppSettings // Ayarlara erişim için
    
    // Grafikte bir dilim seçildiğinde o bilgiyi tutacak state
    @State private var secilenTutar: Double?
    @State private var secilenKategoriAdi: String?

    var body: some View {
        Chart(data) { harcama in
            SectorMark(
                angle: .value("Tutar", harcama.tutar),
                innerRadius: .ratio(0.65),
                angularInset: 1.5
            )
            .cornerRadius(8)
            .foregroundStyle(harcama.renk)
            .shadow(color: .black.opacity(0.3), radius: 2, x: 1, y: 1)
            .offset(x: secilenKategoriAdi == harcama.kategori ? 10 : 0, y: secilenKategoriAdi == harcama.kategori ? -10 : 0)
        }
        .chartBackground { chartProxy in
            GeometryReader { geometry in
                if let anchor = chartProxy.plotFrame {
                    let frame = geometry[anchor]
                    VStack {
                        // --- 🔥 KESİN ÇÖZÜM BURADA 🔥 ---
                        // 1. Uygulamanın kullandığı doğru dil paketini alıyoruz.
                        let bundle = Bundle.getLanguageBundle(for: appSettings.languageCode)
                        
                        // 2. Seçili kategori adını veya "Toplam Tutar" anahtarını bu paketle çeviriyoruz.
                        let titleKey = secilenKategoriAdi ?? "common.total_amount"
                        let title = bundle.localizedString(forKey: titleKey, value: titleKey, table: nil)
                        
                        Text(title)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        // 3. Para birimini de appSettings'ten alarak doğru formatlıyoruz.
                        Text(formatCurrency(
                            amount: secilenTutar ?? data.reduce(0, { $0 + $1.tutar }),
                            currencyCode: appSettings.currencyCode,
                            localeIdentifier: appSettings.languageCode
                        ))
                        .font(.title2.bold())
                        // --- 🔥 ÇÖZÜM SONU 🔥 ---
                    }
                    .position(x: frame.midX, y: frame.midY)
                }
            }
        }
        .chartGesture { chart in
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let bundle = Bundle.getLanguageBundle(for: appSettings.languageCode)
                    
                    // Bu mantık, aynı tutarda iki kategori varsa sorun çıkarabilir ama şimdilik çalışacaktır.
                    if let (tutar, _) = chart.value(at: value.location, as: (Double, String).self) {
                        secilenTutar = tutar
                        if let tamHarcama = data.first(where: { $0.tutar == tutar }) {
                           let key = tamHarcama.localizationKey ?? tamHarcama.kategori
                           secilenKategoriAdi = key // Anahtarı ata, gösterimde çevrilecek
                        }
                    }
                }
                .onEnded { _ in
                    secilenTutar = nil
                    secilenKategoriAdi = nil
                }
        }
        .frame(height: 220)
    }
}
