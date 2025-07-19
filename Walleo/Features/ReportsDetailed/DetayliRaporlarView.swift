// >> GÜNCELLENECEK DOSYA: Features/ReportsDetailed/DetayliRaporlarView.swift

import SwiftUI

struct DetayliRaporlarView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = DetayliRaporlarViewModel()
    
    @State private var secilenRaporTuru: RaporTuru = .harcamalar
    
    enum RaporTuru: String, CaseIterable, Identifiable {
        case harcamalar = "reports.detailed.spending_heatmap"
        case krediKarti = "reports.detailed.credit_card_report"
        case kredi = "reports.detailed.loan_report"
        case kategoriler = "reports.detailed.categories_report" // YENİ
        case nakitAkisi = "reports.detailed.cash_flow" // YENİ
        
        var id: String { self.rawValue }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Başlık ve Picker'ları içeren üst bölüm
                VStack(spacing: 16) { // Spacing artırıldı
                    tarihSecimAlani
                    
                    // --- DEĞİŞİKLİK BURADA BAŞLIYOR ---
                    // Eski Picker yerine yeni oluşturduğumuz kaydırılabilir seçiciyi kullanıyoruz
                    raporTuruSecici
                    // --- DEĞİŞİKLİK BURADA BİTİYOR ---
                }
                .padding()
                .background(.regularMaterial)

                // Rapor içeriğini gösteren switch (Bu kısım aynı)
                switch secilenRaporTuru {
                case .harcamalar:
                    HarcamaIsiHaritasiView(
                        modelContext: modelContext,
                        baslangicTarihi: viewModel.baslangicTarihi,
                        bitisTarihi: viewModel.bitisTarihi
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .krediKarti:
                    KrediKartiRaporuView(
                        modelContext: modelContext,
                        baslangicTarihi: viewModel.baslangicTarihi,
                        bitisTarihi: viewModel.bitisTarihi
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .kredi:
                    KrediRaporuView(
                        modelContext: modelContext,
                        baslangicTarihi: viewModel.baslangicTarihi,
                        bitisTarihi: viewModel.bitisTarihi
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .kategoriler:
                    KategoriRaporuView(
                        modelContext: modelContext,
                        baslangicTarihi: viewModel.baslangicTarihi,
                        bitisTarihi: viewModel.bitisTarihi
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .nakitAkisi:
                    NakitAkisiRaporuView(
                        modelContext: modelContext,
                        baslangicTarihi: viewModel.baslangicTarihi,
                        bitisTarihi: viewModel.bitisTarihi
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("reports.detailed.title")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .onChange(of: viewModel.baslangicTarihi) { viewModel.fetchData() }
            .onChange(of: viewModel.bitisTarihi) { viewModel.fetchData() }
            .onAppear { viewModel.fetchData() }
        }
    }
    
    private var tarihSecimAlani: some View {
        HStack(spacing: 16) {
            // Başlangıç Tarihi
            VStack(alignment: .leading, spacing: 4) {
                Text("reports.detailed.start_date")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                DatePicker(
                    "reports.detailed.start_date",
                    selection: $viewModel.baslangicTarihi,
                    in: ...viewModel.bitisTarihi,
                    displayedComponents: .date
                )
                .labelsHidden()
            }
            
            // Bitiş Tarihi
            VStack(alignment: .leading, spacing: 4) {
                Text("reports.detailed.end_date")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                DatePicker(
                    "reports.detailed.end_date",
                    selection: $viewModel.bitisTarihi,
                    in: viewModel.baslangicTarihi...,
                    displayedComponents: .date
                )
                .labelsHidden()
            }
        }
        .font(.subheadline)
    }
    
    private var raporTuruSecici: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(RaporTuru.allCases) { tur in
                    Text(LocalizedStringKey(tur.rawValue))
                        .font(.subheadline)
                        .fontWeight(secilenRaporTuru == tur ? .semibold : .regular)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(
                            secilenRaporTuru == tur ? Color.accentColor.opacity(0.2) : Color(.secondarySystemGroupedBackground)
                        )
                        .foregroundColor(secilenRaporTuru == tur ? .accentColor : .primary)
                        .clipShape(Capsule())
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3)) {
                                secilenRaporTuru = tur
                            }
                        }
                }
            }
        }
    }
}
