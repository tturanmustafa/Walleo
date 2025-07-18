//
//  KrediRaporuView.swift
//  Walleo
//
//  Created by Mustafa Turan on 14.07.2025.
//


// >> YENİ DOSYA: Features/Reports/Views/KrediRaporuView.swift

import SwiftUI
import SwiftData

struct KrediRaporuView: View {
    // --- DÜZELTME 1: @StateObject yerine @State kullanılıyor ---
    @State private var viewModel: KrediRaporuViewModel
    @EnvironmentObject var appSettings: AppSettings // <--- appSettings'i ekle

    
    let baslangicTarihi: Date
    let bitisTarihi: Date

    init(modelContext: ModelContext, baslangicTarihi: Date, bitisTarihi: Date) {
        self.baslangicTarihi = baslangicTarihi
        self.bitisTarihi = bitisTarihi
        
        // --- DÜZELTME 2: StateObject(wrappedValue:) yerine State(initialValue:) kullanılıyor ---
        _viewModel = State(initialValue: KrediRaporuViewModel(
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
                } else if viewModel.krediDetayRaporlari.isEmpty {
                    ContentUnavailableView(
                        "Veri Bulunamadı",
                        systemImage: "banknote.fill",
                        description: Text("Seçilen tarih aralığında kredi taksiti bulunamadı.")
                    )
                    .padding(.top, 100)
                } else {
                    // Genel özet kartı
                    KrediGenelOzetKarti(ozet: viewModel.genelOzet)
                        .environmentObject(appSettings) // <--- environmentObject'i geçir
                        .padding(.horizontal)
                    
                    // Her kredi için detay paneli
                    ForEach(viewModel.krediDetayRaporlari) { rapor in
                        krediDetayPaneli(rapor: rapor)
                            .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
        .onAppear { Task { await viewModel.fetchData() } }
        // --- KESİN ÇÖZÜMÜN EKLENDİĞİ YER ---
        .onChange(of: baslangicTarihi) {
            viewModel.baslangicTarihi = baslangicTarihi
            viewModel.bitisTarihi = bitisTarihi
            Task { await viewModel.fetchData() }
        }
        .onChange(of: bitisTarihi) {
            viewModel.baslangicTarihi = baslangicTarihi
            viewModel.bitisTarihi = bitisTarihi
            Task { await viewModel.fetchData() }
        }
    }
    
    @ViewBuilder
    private func krediDetayPaneli(rapor: KrediDetayRaporu) -> some View {
        DisclosureGroup {
            VStack(spacing: 15) {
                TaksitListesiBolumu(
                    baslikKey: "reports.detailed.paid_and_expensed",
                    taksitler: rapor.odenenTaksitler.filter { viewModel.giderOlarakEklenenTaksitIDleri.contains($0.id) },
                    ikon: "checkmark.circle.fill",
                    renk: .green
                )
                TaksitListesiBolumu(
                    baslikKey: "reports.detailed.paid_only",
                    taksitler: rapor.odenenTaksitler.filter { !viewModel.giderOlarakEklenenTaksitIDleri.contains($0.id) },
                    ikon: "checkmark.circle",
                    renk: .blue
                )
                TaksitListesiBolumu(
                    baslikKey: "reports.detailed.overdue",
                    taksitler: rapor.odenmeyenTaksitler,
                    ikon: "exclamationmark.circle.fill",
                    renk: .red
                )
                TaksitListesiBolumu(
                    baslikKey: "reports.detailed.upcoming",
                    taksitler: rapor.gelecekTaksitler,
                    ikon: "calendar.circle.fill",
                    renk: .gray
                )
            }
            .padding(.top)
        } label: {
            HStack {
                Image(systemName: rapor.hesap.ikonAdi)
                    .font(.title)
                    .foregroundColor(rapor.hesap.renk)
                VStack(alignment: .leading) {
                    Text(rapor.hesap.isim)
                        .font(.headline)
                    Text(String(format: NSLocalizedString("reports.detailed.installments_in_period", comment: ""), rapor.donemdekiTaksitler.count))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

// Genel kredi özetini gösteren kart
struct KrediGenelOzetKarti: View {
    let ozet: KrediGenelOzet
    @EnvironmentObject var appSettings: AppSettings // <--- 1. AppSettings'i ekle

    var body: some View {
        // --- 2. Metinleri burada oluştur ---
        let dilKodu = appSettings.languageCode
        guard let path = Bundle.main.path(forResource: dilKodu, ofType: "lproj"),
              let languageBundle = Bundle(path: path) else {
            // Hata durumunda boş metinler
            return AnyView(EmptyView())
        }
        
        let aktifKrediMetni = String(
            format: languageBundle.localizedString(forKey: "reports.detailed.active_loan_count", value: "", table: nil),
            ozet.aktifKrediSayisi
        )
        let odenenTaksitMetni = String(
            format: languageBundle.localizedString(forKey: "reports.detailed.paid_installments_count", value: "", table: nil),
            ozet.odenenTaksitSayisi
        )
        let odenmeyenTaksitMetni = String(
            format: languageBundle.localizedString(forKey: "reports.detailed.unpaid_installments_count", value: "", table: nil),
            ozet.odenmeyenTaksitSayisi
        )
        let toplamTaksitTutariMetni = formatCurrency(
            amount: ozet.donemdekiToplamTaksitTutari,
            currencyCode: appSettings.currencyCode,
            localeIdentifier: appSettings.languageCode
        )

        // --- 3. View'da bu metinleri kullan ---
        return AnyView(
            VStack(alignment: .leading, spacing: 16) {
                Text("reports.detailed.overall_loan_summary")
                    .font(.title2.bold())
                
                HStack {
                    Text(toplamTaksitTutariMetni) // Değişti
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    Spacer()
                    Text(aktifKrediMetni) // Değişti
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
                
                ProgressView(value: ozet.odenenToplamTaksitTutari, total: ozet.donemdekiToplamTaksitTutari > 0 ? ozet.donemdekiToplamTaksitTutari : 1)
                    .tint(.blue)
                
                HStack {
                    Text(odenenTaksitMetni) // Değişti
                        .font(.caption)
                    Spacer()
                    Text(odenmeyenTaksitMetni) // Değişti
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
        )
    }
}

// Açılır/kapanır taksit listelerini gösteren yardımcı view
struct TaksitListesiBolumu: View {
    let baslikKey: LocalizedStringKey
    let taksitler: [KrediTaksitDetayi]
    let ikon: String
    let renk: Color
    
    var body: some View {
        if !taksitler.isEmpty {
            DisclosureGroup {
                ForEach(taksitler) { taksit in
                    HStack {
                        Text(taksit.odemeTarihi, style: .date)
                        Spacer()
                        Text(formatCurrency(amount: taksit.taksitTutari, currencyCode: "TRY", localeIdentifier: "tr_TR"))
                    }
                    .font(.footnote)
                    .padding(.vertical, 2)
                }
            } label: {
                HStack {
                    Image(systemName: ikon)
                        .foregroundColor(renk)
                    Text(baslikKey)
                    Spacer()
                    Text("\(taksitler.count)")
                }
                .font(.headline)
            }
        }
    }
}
