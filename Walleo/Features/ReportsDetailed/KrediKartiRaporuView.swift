//
//  KrediKartiRaporuView.swift
//  Walleo
//
//  Created by Mustafa Turan on 14.07.2025.
//


// >> YENİ DOSYA: Features/Reports/Views/KrediKartiRaporuView.swift

import SwiftUI
import SwiftData

struct KategoriLegendiView: View {
    let kategoriler: [KategoriHarcamasi]
    let toplamTutar: Double
    @EnvironmentObject var appSettings: AppSettings

    var body: some View {
        VStack(spacing: 14) {
            ForEach(kategoriler) { kategori in
                HStack(spacing: 12) {
                    Image(systemName: kategori.ikonAdi)
                        .font(.callout)
                        .foregroundColor(kategori.renk)
                        .frame(width: 38, height: 38)
                        .background(kategori.renk.opacity(0.15))
                        .cornerRadius(8)
                    
                    Text(LocalizedStringKey(kategori.localizationKey ?? kategori.kategori))
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(formatCurrency(
                            amount: kategori.tutar,
                            currencyCode: appSettings.currencyCode,
                            localeIdentifier: appSettings.languageCode
                        ))
                        .font(.callout.bold())
                        
                        if toplamTutar > 0 {
                            Text(String(format: "%.1f%%", (kategori.tutar / toplamTutar) * 100))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding(.top, 15)
    }
}

struct KrediKartiRaporuView: View {
    @Environment(\.modelContext) private var modelContext
    
    // --- DÜZELTME 1: @StateObject yerine @State kullanılıyor ---
    @State private var viewModel: KrediKartiRaporuViewModel
    @EnvironmentObject var appSettings: AppSettings

    let baslangicTarihi: Date
    let bitisTarihi: Date
    
    @State private var acikPaneller: Set<UUID> = []

    init(modelContext: ModelContext, baslangicTarihi: Date, bitisTarihi: Date) {
        self.baslangicTarihi = baslangicTarihi
        self.bitisTarihi = bitisTarihi
        
        // --- DÜZELTME 2: StateObject(wrappedValue:) yerine State(initialValue:) kullanılıyor ---
        _viewModel = State(initialValue: KrediKartiRaporuViewModel(
            modelContext: modelContext,
            baslangicTarihi: baslangicTarihi,
            bitisTarihi: bitisTarihi
        ))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if viewModel.isLoading {
                    ProgressView("Yükleniyor...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.top, 100)
                } else if viewModel.kartDetayRaporlari.isEmpty {
                    ContentUnavailableView(
                        "Veri Bulunamadı",
                        systemImage: "creditcard.fill",
                        description: Text("Seçilen tarih aralığında kredi kartı harcaması bulunamadı.")
                    )
                    .padding(.top, 100)
                } else {
                    // Genel özet kartı
                    GenelOzetKarti(ozet: viewModel.genelOzet)
                        .padding(.horizontal)
                    
                    // Her kart için detay paneli
                    ForEach(viewModel.kartDetayRaporlari) { rapor in
                        kartDetayPaneli(rapor: rapor)
                            .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
        .onAppear { Task { await viewModel.fetchData() } }
        // --- KESİN ÇÖZÜMÜN EKLENDİĞİ YER ---
        // Dışarıdan gelen 'baslangicTarihi' değiştiğinde,
        // viewModel'ın içindeki tarihi güncelle ve veriyi yeniden çek.
        .onChange(of: baslangicTarihi) {
            viewModel.baslangicTarihi = baslangicTarihi
            viewModel.bitisTarihi = bitisTarihi // Bitişi de güncellemek iyi bir pratik
            Task { await viewModel.fetchData() }
        }
        // Aynı kontrolü bitiş tarihi için de yapıyoruz.
        .onChange(of: bitisTarihi) {
            viewModel.baslangicTarihi = baslangicTarihi
            viewModel.bitisTarihi = bitisTarihi
            Task { await viewModel.fetchData() }
        }
    }
    
    @ViewBuilder
    private func kartDetayPaneli(rapor: KartDetayRaporu) -> some View {
        DisclosureGroup(
            isExpanded: Binding<Bool>(
                get: { acikPaneller.contains(rapor.id) },
                set: { isExpanded in
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        if isExpanded {
                            acikPaneller.insert(rapor.id)
                        } else {
                            acikPaneller.remove(rapor.id)
                        }
                    }
                }
            ),
            content: {
                VStack(alignment: .leading, spacing: 25) {
                    // 1. 3D Donut Grafik ve Lejantı
                    Text("reports.detailed.category_distribution")
                        .font(.headline)
                        .padding(.top)
                    
                    DonutChartView(data: rapor.kategoriDagilimi)
                    
                    KategoriLegendiView(kategoriler: rapor.kategoriDagilimi, toplamTutar: rapor.toplamHarcama)
                        .environmentObject(appSettings)
                    
                    Divider()
                    
                    // 2. İnteraktif Çizgi Grafik (Artık kendi başlığını içeriyor)
                    // --- DEĞİŞEN SATIRLAR ---
                    InteractiveLineChartView(data: rapor.gunlukHarcamaTrendi, renk: rapor.hesap.renk)
                        .environmentObject(appSettings) // EnvironmentObject'i buraya da geçiyoruz
                    // --- DEĞİŞİKLİK SONU ---
                }
                .padding(.top)
                .frame(maxWidth: .infinity)
            },
            label: {
                kartDetayLabel(rapor: rapor)
            }
        )
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    @ViewBuilder
    private func kartDetayLabel(rapor: KartDetayRaporu) -> some View {
        HStack {
            Image(systemName: rapor.hesap.ikonAdi)
                .font(.title)
                .foregroundColor(rapor.hesap.renk)
            VStack(alignment: .leading) {
                Text(rapor.hesap.isim)
                    .font(.headline)
                Text(formatCurrency(amount: rapor.toplamHarcama, currencyCode: "TRY", localeIdentifier: "tr_TR"))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .contentShape(Rectangle())
    }
}

// Genel özeti gösteren kart
struct GenelOzetKarti: View {
    let ozet: KrediKartiGenelOzet
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("reports.detailed.overall_summary")
                .font(.title2.bold())
            
            HStack(spacing: 20) {
                MetrikView(baslikKey: "reports.detailed.total_spending", deger: formatCurrency(amount: ozet.toplamHarcama, currencyCode: "TRY", localeIdentifier: "tr_TR"), ikonAdi: "cart.fill", renk: .red)
                Divider()
                MetrikView(baslikKey: "reports.detailed.transaction_count", deger: "\(ozet.islemSayisi)", ikonAdi: "number.circle.fill", renk: .blue)
            }
            
            if let kart = ozet.enCokKullanilanKart {
                Divider()
                HStack {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                    Text("reports.detailed.most_used_card")
                    Spacer()
                    Text(kart.isim)
                        .fontWeight(.bold)
                }
                .font(.subheadline)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

// Küçük metrikleri gösteren yardımcı view
private struct MetrikView: View {
    let baslikKey: LocalizedStringKey
    let deger: String
    let ikonAdi: String
    let renk: Color
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Image(systemName: ikonAdi)
                    .foregroundColor(renk)
                Text(baslikKey)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Text(deger)
                .font(.title3.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

