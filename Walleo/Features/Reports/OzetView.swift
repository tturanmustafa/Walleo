// GÜNCELLEME: OzetView.swift
import SwiftUI

struct OzetView<ViewModel: RaporViewModelProtocol>: View {
    // GÜNCELLEME: @Bindable kaldırıldı. Bu görünüm ViewModel'ı sadece
    // okuduğu için özel bir etikete ihtiyaç yok.
    let viewModel: ViewModel
    @EnvironmentObject var appSettings: AppSettings
    
    var body: some View {
        if viewModel.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            // ... Geri kalan kod tamamen aynı ...
            ScrollView {
                VStack(alignment: .center, spacing: 20) {
                    
                    AnaMetriklerCard(ozetVerisi: viewModel.ozetVerisi)
                        .environmentObject(appSettings)

                    KarsilastirmaCard(karsilastirmaVerisi: viewModel.karsilastirmaVerisi)
                        .environmentObject(appSettings)
                        
                    if !viewModel.topGiderKategorileri.isEmpty {
                        KategoriOzetleriCardView(
                            baslikKey: "reports.summary.top_expenses",
                            kategoriler: viewModel.topGiderKategorileri,
                            showDivider: true
                        )
                        .environmentObject(appSettings)
                    }
                    
                    IstatistiklerCard(
                        baslikKey: "reports.summary.statistics",
                        ozetVerisi: viewModel.ozetVerisi
                    )
                    .environmentObject(appSettings)
                }
                .padding()
            }
        }
    }
}
