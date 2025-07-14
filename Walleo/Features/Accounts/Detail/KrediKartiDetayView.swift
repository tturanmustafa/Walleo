// Dosya: KrediKartiDetayView.swift

import SwiftUI
import SwiftData

struct KrediKartiDetayView: View {
    @EnvironmentObject var appSettings: AppSettings
    @Environment(\.modelContext) private var modelContext
    
    @State private var viewModel: KrediKartiDetayViewModel
    
    @State private var duzenlenecekIslem: Islem?
    @State private var silinecekTekilIslem: Islem?
    @State private var silinecekTekrarliIslem: Islem?
    @State private var isDeletingSeries: Bool = false
    
    init(kartHesabi: Hesap, modelContext: ModelContext) {
        _viewModel = State(initialValue: KrediKartiDetayViewModel(modelContext: modelContext, kartHesabi: kartHesabi))
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                MonthNavigatorView(currentDate: $viewModel.currentDate)
                    .padding(.bottom, 10)
                
                if viewModel.toplamHarcama > 0 {
                    DonemHarcamaOzetKarti(toplamTutar: viewModel.toplamHarcama)
                        .padding(.horizontal)
                        .padding(.bottom, 10)
                }
                
                List {
                    ForEach(viewModel.donemIslemleri) { islem in
                        IslemSatirView(
                            islem: islem,
                            onEdit: { duzenlenecekIslem = islem },
                            onDelete: { silmeyiBaslat(islem) }
                        )
                    }
                }
                .listStyle(.plain)
                .overlay {
                    if viewModel.donemIslemleri.isEmpty && !isDeletingSeries {
                        // GÜNCELLEME: Var olmayan 'creditcard.slash' ikonu, 'creditcard.fill' ile değiştirildi.
                        ContentUnavailableView(
                            LocalizedStringKey("credit_card_details.no_expenses_for_month"),
                            systemImage: "creditcard.fill"
                        )
                    }
                }
            }
            .disabled(isDeletingSeries)
            
            if isDeletingSeries {
                ProgressView("Seri Siliniyor...")
                    .padding(25)
                    .background(Material.thick)
                    .cornerRadius(10)
                    .shadow(radius: 5)
            }
        }
        .navigationTitle(viewModel.kartHesabi.isim)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            viewModel.islemleriGetir()
        }
        .sheet(item: $duzenlenecekIslem) { islem in
            IslemEkleView(duzenlenecekIslem: islem)
                .environmentObject(appSettings)
        }
        .confirmationDialog(
            LocalizedStringKey("alert.recurring_transaction"),
            isPresented: Binding(isPresented: $silinecekTekrarliIslem),
            presenting: silinecekTekrarliIslem
        ) { islem in
            Button("alert.delete_this_only", role: .destructive) {
                TransactionService.shared.deleteTransaction(islem, in: modelContext)
            }
            Button("alert.delete_series", role: .destructive) {
                Task {
                    isDeletingSeries = true
                    await TransactionService.shared.deleteSeriesInBackground(tekrarID: islem.tekrarID, from: modelContext.container)
                    isDeletingSeries = false
                }
            }
            Button("common.cancel", role: .cancel) { }
        }
        .alert(
            LocalizedStringKey("alert.delete_confirmation.title"),
            isPresented: Binding(isPresented: $silinecekTekilIslem),
            presenting: silinecekTekilIslem
        ) { islem in
            Button(role: .destructive) {
                TransactionService.shared.deleteTransaction(islem, in: modelContext)
            } label: { Text("common.delete") }
        } message: { islem in
            Text("alert.delete_transaction.message")
        }
    }
    
    private func silmeyiBaslat(_ islem: Islem) {
        if islem.tekrar != .tekSeferlik && islem.tekrarID != UUID() {
            silinecekTekrarliIslem = islem
        } else {
            silinecekTekilIslem = islem
        }
    }
}
