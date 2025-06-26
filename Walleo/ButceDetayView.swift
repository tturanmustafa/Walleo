import SwiftUI
import SwiftData

struct ButceDetayView: View {
    @EnvironmentObject var appSettings: AppSettings
    @Environment(\.modelContext) private var modelContext
    
    @State private var viewModel: ButceDetayViewModel
    
    // YENİ EKLENEN STATE'LER: Düzenleme ve silme işlemleri için
    @State private var duzenlenecekIslem: Islem?
    @State private var silinecekTekilIslem: Islem?
    @State private var silinecekTekrarliIslem: Islem?
    @State private var isDeletingSeries: Bool = false
    
    private var gruplanmisIslemler: [Date: [Islem]] {
        Dictionary(grouping: viewModel.donemIslemleri) { islem in
            Calendar.current.startOfDay(for: islem.tarih)
        }
    }
    
    private var siraliGunler: [Date] {
        gruplanmisIslemler.keys.sorted(by: >)
    }

    init(butce: Butce, modelContext: ModelContext) {
        _viewModel = State(initialValue: ButceDetayViewModel(modelContext: modelContext, butce: butce))
    }

    var body: some View {
        // YENİ: ZStack ve ProgressView eklendi
        ZStack {
            List {
                if let gosterilecekButce = viewModel.gosterilecekButce {
                    Section {
                        ButceKartView(gosterilecekButce: gosterilecekButce)
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
                                // GÜNCELLENDİ: onEdit ve onDelete eylemleri eklendi
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
            .disabled(isDeletingSeries) // Seri silinirken arayüzü pasif yap
            
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
        .task {
            await viewModel.fetchData()
        }
        // YENİ EKLENEN MODIFIER'LAR
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
    
    // YENİ EKLENEN FONKSİYON
    private func silmeyiBaslat(_ islem: Islem) {
        if islem.tekrar != .tekSeferlik && islem.tekrarID != UUID() {
            silinecekTekrarliIslem = islem
        } else {
            silinecekTekilIslem = islem
        }
    }
}
