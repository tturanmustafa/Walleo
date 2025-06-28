//
//  CuzdanDetayView.swift
//  Walleo
//
//  Created by Mustafa Turan on 28.06.2025.
//


// YENİ DOSYA: CuzdanDetayView.swift

import SwiftUI
import SwiftData

struct CuzdanDetayView: View {
    @EnvironmentObject var appSettings: AppSettings
    @Environment(\.modelContext) private var modelContext
    
    @State private var viewModel: CuzdanDetayViewModel
    
    @State private var duzenlenecekIslem: Islem?
    @State private var silinecekTekilIslem: Islem?
    @State private var silinecekTekrarliIslem: Islem?
    
    init(hesap: Hesap) {
        _viewModel = State(initialValue: CuzdanDetayViewModel(modelContext: try! ModelContext(ModelContainer(for: Islem.self)), hesap: hesap))
    }

    var body: some View {
        VStack(spacing: 0) {
            MonthNavigatorView(currentDate: $viewModel.currentDate)
                .padding(.bottom, 10)
            
            AylikHesapOzetiKarti(toplamGelir: viewModel.toplamGelir, toplamGider: viewModel.toplamGider)
                .padding(.horizontal)
                .padding(.bottom, 10)
            
            List {
                ForEach(viewModel.donemIslemleri) { islem in
                    IslemSatirView(islem: islem, onEdit: { duzenlenecekIslem = islem }, onDelete: { silmeyiBaslat(islem) })
                }
            }
            .listStyle(.plain)
            .overlay {
                if viewModel.donemIslemleri.isEmpty {
                    ContentUnavailableView(
                        "Bu Ay İşlem Yok",
                        systemImage: "wallet.pass.fill"
                    )
                }
            }
        }
        .navigationTitle(viewModel.hesap.isim)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // View ilk açıldığında doğru context ile viewModel'ı oluştur.
            viewModel = CuzdanDetayViewModel(modelContext: self.modelContext, hesap: viewModel.hesap)
        }
        .sheet(item: $duzenlenecekIslem) { islem in
            IslemEkleView(duzenlenecekIslem: islem).environmentObject(appSettings)
        }
        .recurringTransactionAlert(for: $silinecekTekrarliIslem, onDeleteSingle: { islem in TransactionService.shared.deleteTransaction(islem, in: modelContext) }, onDeleteSeries: { islem in Task { await TransactionService.shared.deleteSeriesInBackground(tekrarID: islem.tekrarID, from: modelContext.container) }})
        .alert(LocalizedStringKey("alert.delete_confirmation.title"), isPresented: Binding(isPresented: $silinecekTekilIslem), presenting: silinecekTekilIslem) { islem in
            Button(role: .destructive) { TransactionService.shared.deleteTransaction(islem, in: modelContext) } label: { Text("common.delete") }
        } message: { islem in Text("alert.delete_transaction.message") }
    }
    
    private func silmeyiBaslat(_ islem: Islem) {
        if islem.tekrar != .tekSeferlik && islem.tekrarID != UUID() {
            silinecekTekrarliIslem = islem
        } else {
            silinecekTekilIslem = islem
        }
    }
}