// >> GÜNCELLENECEK DOSYA: Features/Reports/DetayliRaporlarView.swift

import SwiftUI

struct DetayliRaporlarView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = DetayliRaporlarViewModel()
    
    @State private var secilenRaporTuru: RaporTuru = .krediKarti
    
    enum RaporTuru: String, CaseIterable, Identifiable {
        case krediKarti = "reports.detailed.credit_card_report"
        case kredi = "reports.detailed.loan_report"
        
        var id: String { self.rawValue }
    }

    var body: some View {
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
            case .krediKarti:
                KrediKartiRaporuView(
                    modelContext: modelContext,
                    baslangicTarihi: viewModel.baslangicTarihi,
                    bitisTarihi: viewModel.bitisTarihi
                )
            case .kredi:
                KrediRaporuView(
                    modelContext: modelContext,
                    baslangicTarihi: viewModel.baslangicTarihi,
                    bitisTarihi: viewModel.bitisTarihi
                )
            }
            
            // --- EKLENECEK SATIR ---
            // Bu Spacer, içerik görünümlerine render edilecek alanı verir
            // ve bomboş ekran sorununu çözer.
            Spacer()
        }
        .navigationTitle("reports.detailed.title")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: viewModel.baslangicTarihi) { viewModel.fetchData() }
        .onChange(of: viewModel.bitisTarihi) { viewModel.fetchData() }
    }
    
    // --- DÜZELTME 2: Tarih seçicilere etiketler eklendi ---
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
