//
//  DonutChartView.swift
//  Walleo
//
//  Created by Mustafa Turan on 14.07.2025.
//


// >> YENİ DOSYA: Features/Reports/Views/DonutChartView.swift

import SwiftUI
import Charts

struct DonutChartView: View {
    let data: [KategoriHarcamasi]
    
    // Grafikte bir dilim seçildiğinde o bilgiyi tutacak state
    @State private var secilenTutar: Double?
    @State private var secilenKategoriAdi: String?

    var body: some View {
        Chart(data) { harcama in
            // 3D efekti için her dilime bir gölge ekliyoruz.
            SectorMark(
                angle: .value("Tutar", harcama.tutar),
                innerRadius: .ratio(0.65),
                angularInset: 1.5 // Dilimler arası boşluk
            )
            .cornerRadius(8)
            .foregroundStyle(harcama.renk)
            .shadow(color: .black.opacity(0.3), radius: 2, x: 1, y: 1)
            // Seçilen dilimi hafifçe dışarı çıkaran animasyon
            .offset(x: secilenKategoriAdi == harcama.kategori ? 10 : 0, y: secilenKategoriAdi == harcama.kategori ? -10 : 0)
            
        }
        // Grafiğin ortasında seçili dilimin bilgisini gösteren bölüm
        .chartBackground { chartProxy in
            GeometryReader { geometry in
                if let anchor = chartProxy.plotFrame {
                    let frame = geometry[anchor]
                    VStack {
                        // --- DEĞİŞEN SATIR ---
                        Text(secilenKategoriAdi ?? NSLocalizedString("common.total_amount", comment: "")) // "Kategori Dağılımı" yerine "Toplam Tutar"
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        // --- DEĞİŞİKLİK SONU ---
                        Text(formatCurrency(
                            amount: secilenTutar ?? data.reduce(0, { $0 + $1.tutar }),
                            currencyCode: "TRY",
                            localeIdentifier: "tr_TR"
                        ))
                        .font(.title2.bold())
                    }
                    .position(x: frame.midX, y: frame.midY)
                }
            }
        }
        // Grafik üzerinde gezinme (dokunma) hareketini yakalayan bölüm
        .chartGesture { chart in
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    // --- DÜZELTME BURADA ---
                    // 'origin' hesaplaması kaldırıldı. value.location doğrudan kullanılıyor.
                    if let (tutar, kategori) = chart.value(at: value.location, as: (Double, String).self) {
                        secilenTutar = tutar
                        if let tamHarcama = data.first(where: { $0.tutar == tutar }) {
                           secilenKategoriAdi = NSLocalizedString(tamHarcama.localizationKey ?? tamHarcama.kategori, comment: "")
                        }
                    }
                }
                .onEnded { _ in
                    // Dokunma bittiğinde seçimi sıfırla
                    secilenTutar = nil
                    secilenKategoriAdi = nil
                }
        }
        .frame(height: 220) // Sabit bir yükseklik vererek animasyonların pürüzsüz olmasını sağlıyoruz.
    }
}
