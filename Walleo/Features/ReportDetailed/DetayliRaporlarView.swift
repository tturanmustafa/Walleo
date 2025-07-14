//
//  DetayliRaporlarView.swift
//  Walleo
//
//  Created by Mustafa Turan on 14.07.2025.
//


import SwiftUI
import SwiftData

struct DetayliRaporlarView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appSettings: AppSettings
    
    @StateObject private var viewModel = DetayliRaporlarViewModel()
    @State private var secilenRapor: RaporTuru = .nakitAkisi
    @State private var tarihSeciciGoster = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tarih Seçici
                tarihSeciciHeader
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                
                // Rapor Menüsü
                raporMenusu
                
                Divider()
                
                // İçerik
                ZStack {
                    if viewModel.yuklemeDurumu == .yukleniyor {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        raporIcerigi
                    }
                }
                .animation(.easeInOut, value: secilenRapor)
            }
            .navigationTitle("tab.detailed_reports")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $tarihSeciciGoster) {
                TarihAraligiSeciciSheet(
                    baslangicTarihi: $viewModel.baslangicTarihi,
                    bitisTarihi: $viewModel.bitisTarihi
                )
                .presentationDetents([.height(400)])
                .presentationDragIndicator(.visible)
            }
            .task {
                viewModel.configure(with: modelContext)
                await viewModel.veriYukle(tur: secilenRapor)
            }
            .onChange(of: secilenRapor) { _, yeniDeger in
                Task {
                    await viewModel.veriYukle(tur: yeniDeger)
                }
            }
            .onChange(of: viewModel.baslangicTarihi) { _, _ in
                Task {
                    await viewModel.veriYukle(tur: secilenRapor)
                }
            }
            .onChange(of: viewModel.bitisTarihi) { _, _ in
                Task {
                    await viewModel.veriYukle(tur: secilenRapor)
                }
            }
        }
    }
    
    private var tarihSeciciHeader: some View {
        Button(action: { tarihSeciciGoster = true }) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.accentColor)
                
                Text(formatDateRange(
                    from: viewModel.baslangicTarihi,
                    to: viewModel.bitisTarihi,
                    locale: appSettings.languageCode
                ))
                .font(.subheadline)
                .fontWeight(.medium)
                
                Spacer()
                
                Image(systemName: "chevron.down")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
    
    private var raporMenusu: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(RaporTuru.allCases) { rapor in
                    RaporMenuButton(
                        rapor: rapor,
                        secili: secilenRapor == rapor,
                        action: { secilenRapor = rapor }
                    )
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }
    
    @ViewBuilder
    private var raporIcerigi: some View {
        ScrollView {
            switch secilenRapor {
            case .nakitAkisi:
                NakitAkisiRaporView(viewModel: viewModel)
            case .kategoriRadari:
                KategoriRadariView(viewModel: viewModel)
            case .harcamaAliskanliklari:
                HarcamaAliskanliklariView(viewModel: viewModel)
            case .gelirVeHesaplar:
                GelirVeHesaplarView(viewModel: viewModel)
            case .borcYonetimi:
                BorcYonetimiView(viewModel: viewModel)
            case .butcePerformansi:
                ButcePerformansiRaporView(viewModel: viewModel)
            case .abonelikler:
                AboneliklerView(viewModel: viewModel)
            case .donemselKarsilastirma:
                DonemselKarsilastirmaView(viewModel: viewModel)
            case .finansalAnlik:
                FinansalAnlikView(viewModel: viewModel)
            }
        }
    }
}

struct RaporMenuButton: View {
    let rapor: RaporTuru
    let secili: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: rapor.ikon)
                    .font(.title2)
                    .foregroundColor(secili ? .white : .accentColor)
                
                Text(rapor.kısaBaslik)
                    .font(.caption)
                    .fontWeight(secili ? .semibold : .regular)
                    .foregroundColor(secili ? .white : .primary)
            }
            .frame(width: 80, height: 80)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(secili ? Color.accentColor : Color(.systemGray6))
            )
            .scaleEffect(secili ? 1.05 : 1.0)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3), value: secili)
    }
}