// Dosya: ButceDetayView.swift

import SwiftUI
import SwiftData

struct ButceDetayView: View {
    @EnvironmentObject var appSettings: AppSettings
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var viewModel: ButceDetayViewModel
    
    // İşlemler için state'ler
    @State private var duzenlenecekIslem: Islem?
    @State private var silinecekTekilIslem: Islem?
    @State private var silinecekTekrarliIslem: Islem?
    @State private var isDeletingSeries: Bool = false
    
    // Bütçenin kendisini düzenlemek ve silmek için state'ler
    @State private var butceDuzenleGoster = false
    @State private var butceSilUyarisiGoster = false
    
    private var gruplanmisIslemler: [Date: [Islem]] {
        Dictionary(grouping: viewModel.donemIslemleri) { islem in
            Calendar.current.startOfDay(for: islem.tarih)
        }
    }
    
    private var siraliGunler: [Date] {
        gruplanmisIslemler.keys.sorted(by: >)
    }

    init(butce: Butce) {
        _viewModel = State(initialValue: ButceDetayViewModel(butce: butce))
    }

    var body: some View {
        ZStack {
            List {
                if let gosterilecekButce = viewModel.gosterilecekButce {
                    Section {
                        ButceKartView(
                            gosterilecekButce: gosterilecekButce,
                            onEdit: {
                                butceDuzenleGoster = true
                            },
                            onDelete: {
                                butceSilUyarisiGoster = true
                            }
                        )
                        .environmentObject(appSettings)
                    }
                }

                if viewModel.donemIslemleri.isEmpty {
                    ContentUnavailableView(
                        LocalizedStringKey("budget_details.no_transactions"),
                        systemImage: "doc.text.magnifyingglass"
                    )
                } else {
                    ForEach(siraliGunler, id: \.self) { gun in
                        Section(header: Text(gun, format: .dateTime.day().month().year())) {
                            ForEach(gruplanmisIslemler[gun] ?? []) { islem in
                                IslemSatirView(
                                    islem: islem,
                                    onEdit: { duzenlenecekIslem = islem },
                                    onDelete: { silmeyiBaslat(islem) }
                                )
                            }
                        }
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
        .navigationTitle(viewModel.butce.isim)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.initialize(modelContext: self.modelContext)
        }
        .sheet(item: $duzenlenecekIslem) { islem in
            IslemEkleView(duzenlenecekIslem: islem)
                .environmentObject(appSettings)
        }
        .sheet(isPresented: $butceDuzenleGoster) {
            ButceEkleDuzenleView(duzenlenecekButce: viewModel.butce)
                .environmentObject(appSettings)
        }
        .alert(
            LocalizedStringKey("alert.delete_confirmation.title"),
            isPresented: $butceSilUyarisiGoster
        ) {
            Button(role: .destructive) {
                deleteBudget()
            } label: { Text("common.delete") }
        } message: {
             let dilKodu = appSettings.languageCode
            guard let path = Bundle.main.path(forResource: dilKodu, ofType: "lproj"),
                  let languageBundle = Bundle(path: path) else {
                return Text(viewModel.butce.isim)
            }
            let formatString = languageBundle.localizedString(forKey: "alert.delete_budget.message_format", value: "", table: nil)
            return Text(String(format: formatString, viewModel.butce.isim))
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
    
    private func deleteBudget() {
        viewModel.deleteButce()
        dismiss()
    }
    
    private func silmeyiBaslat(_ islem: Islem) {
        if islem.tekrar != .tekSeferlik && islem.tekrarID != UUID() {
            silinecekTekrarliIslem = islem
        } else {
            silinecekTekilIslem = islem
        }
    }
}
