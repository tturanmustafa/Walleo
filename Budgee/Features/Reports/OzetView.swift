import SwiftUI

struct OzetView: View {
    @Bindable var viewModel: RaporlarViewModel
    @EnvironmentObject var appSettings: AppSettings
    
    var body: some View {
        if viewModel.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                VStack(alignment: .center, spacing: 20) {
                    
                    // Başlıklar artık Text(LocalizedStringKey(...)) ile çağırılıyor.
                    AnaMetriklerCard(ozetVerisi: viewModel.ozetVerisi)
                        .environmentObject(appSettings)

                    KarsilastirmaCard(karsilastirmaVerisi: viewModel.karsilastirmaVerisi)
                        .environmentObject(appSettings)
                        
                    if !viewModel.topGiderKategorileri.isEmpty {
                        KategoriOzetleriCardView( // <-- YENİ KULLANIM
                            baslikKey: "reports.summary.top_expenses",
                            kategoriler: viewModel.topGiderKategorileri,
                            showDivider: true // Divider'lı versiyon
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
