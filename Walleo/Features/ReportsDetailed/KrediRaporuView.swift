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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("reports.detailed.overall_loan_summary")
                .font(.title2.bold())
            
            HStack {
                Text(formatCurrency(amount: ozet.donemdekiToplamTaksitTutari, currencyCode: "TRY", localeIdentifier: "tr_TR"))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Spacer()
                Text(String(format: NSLocalizedString("reports.detailed.active_loan_count", comment: ""), ozet.aktifKrediSayisi))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
            
            ProgressView(value: ozet.odenenToplamTaksitTutari, total: ozet.donemdekiToplamTaksitTutari > 0 ? ozet.donemdekiToplamTaksitTutari : 1)
                .tint(.blue)
            
            HStack {
                Text(String(format: NSLocalizedString("reports.detailed.paid_installments_count", comment: ""), ozet.odenenTaksitSayisi))
                    .font(.caption)
                Spacer()
                Text(String(format: NSLocalizedString("reports.detailed.unpaid_installments_count", comment: ""), ozet.odenmeyenTaksitSayisi))
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
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
