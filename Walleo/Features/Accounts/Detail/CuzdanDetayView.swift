// Dosya: CuzdanDetayView.swift

import SwiftUI
import SwiftData

struct CuzdanDetayView: View {
    @EnvironmentObject var appSettings: AppSettings
    @Environment(\.modelContext) private var modelContext
    
    @State private var viewModel: CuzdanDetayViewModel
    
    @State private var duzenlenecekIslem: Islem?
    @State private var silinecekTekilIslem: Islem?
    @State private var silinecekTekrarliIslem: Islem?
    @State private var silinecekTaksitliIslem: Islem?
    
    init(hesap: Hesap) {
        _viewModel = State(initialValue: CuzdanDetayViewModel(hesap: hesap))
    }

    var body: some View {
        VStack(spacing: 0) {
            MonthNavigatorView(currentDate: $viewModel.currentDate)
                .padding(.bottom, 10)
            
            AylikHesapOzetiKarti(toplamGelir: viewModel.toplamGelir, toplamGider: viewModel.toplamGider)
                .padding(.horizontal)
                .padding(.bottom, 10)
            
            List {
                // İşlemler Bölümü
                Section(header: Text(LocalizedStringKey("transfer.section.transactions"))) {
                    if viewModel.donemIslemleri.isEmpty {
                        HStack {
                            Spacer()
                            Text(LocalizedStringKey("transfer.no_transactions"))
                                .foregroundColor(.secondary)
                                .padding()
                            Spacer()
                        }
                    } else {
                        ForEach(viewModel.donemIslemleri) { islem in
                            IslemSatirView(
                                islem: islem,
                                onEdit: { duzenlenecekIslem = islem },
                                onDelete: { silmeyiBaslat(islem) }
                            )
                        }
                    }
                }
                
                // Transferler Bölümü
                Section(header: Text(LocalizedStringKey("transfer.section.transfers"))) {
                    if viewModel.tumTransferler.isEmpty {
                        HStack {
                            Spacer()
                            Text(LocalizedStringKey("transfer.no_transfers"))
                                .foregroundColor(.secondary)
                                .padding()
                            Spacer()
                        }
                    } else {
                        ForEach(viewModel.tumTransferler) { transfer in
                            TransferSatirView(
                                transfer: transfer,
                                hesapID: viewModel.hesap.id
                            )
                            .environmentObject(appSettings)
                        }
                    }
                }
            }
            .listStyle(.plain)
        }
        .navigationTitle(viewModel.hesap.isim)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.initialize(modelContext: self.modelContext)
        }
        .sheet(item: $duzenlenecekIslem) { islem in
            IslemEkleView(duzenlenecekIslem: islem).environmentObject(appSettings)
        }
        .recurringTransactionAlert(
            for: $silinecekTekrarliIslem,
            onDeleteSingle: { islem in
                TransactionService.shared.deleteTransaction(islem, in: modelContext)
            },
            onDeleteSeries: { islem in
                Task {
                    await TransactionService.shared.deleteSeriesInBackground(
                        tekrarID: islem.tekrarID,
                        from: modelContext.container
                    )
                }
            }
        )
        .alert(
            LocalizedStringKey("alert.installment.delete_title"),
            isPresented: Binding(isPresented: $silinecekTaksitliIslem),
            presenting: silinecekTaksitliIslem
        ) { islem in
            Button(role: .destructive) {
                TransactionService.shared.deleteTaksitliIslem(islem, in: modelContext)
            } label: {
                Text("common.delete")
            }
        } message: { islem in
            Text(String(format: NSLocalizedString("transaction.installment.delete_warning", comment: ""), islem.toplamTaksitSayisi))
        }
        .alert(
            LocalizedStringKey("alert.delete_confirmation.title"),
            isPresented: Binding(isPresented: $silinecekTekilIslem),
            presenting: silinecekTekilIslem
        ) { islem in
            Button(role: .destructive) {
                TransactionService.shared.deleteTransaction(islem, in: modelContext)
            } label: {
                Text("common.delete")
            }
        } message: { islem in
            Text("alert.delete_transaction.message")
        }
    }
    
    private func silmeyiBaslat(_ islem: Islem) {
        if islem.taksitliMi {
            silinecekTaksitliIslem = islem
        } else if islem.tekrar != .tekSeferlik && islem.tekrarID != UUID() {
            silinecekTekrarliIslem = islem
        } else {
            silinecekTekilIslem = islem
        }
    }
}
