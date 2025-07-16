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
        
        var id: String { self.rawValue }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Başlık ve Picker'ları içeren üst bölüm
                VStack {
                    tarihSecimAlani
                    
                    Picker("Rapor Türü", selection: $secilenRaporTuru) {
                        ForEach(RaporTuru.allCases) { tur in
                            Text(LocalizedStringKey(tur.rawValue)).tag(tur)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding()
                .background(.regularMaterial)

                // Rapor içeriğini gösteren switch
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
                case .kategoriler: // YENİ
                    KategoriRaporuView(
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
}
