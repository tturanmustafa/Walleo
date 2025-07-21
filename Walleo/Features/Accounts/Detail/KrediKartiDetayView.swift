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
    @State private var silinecekTaksitliIslem: Islem?
    @State private var isDeletingSeries: Bool = false
    
    // YENİ: Taksitli işlem grubunu açık/kapalı tutmak için
    @State private var expandedGroups: Set<UUID> = []
    
    init(kartHesabi: Hesap, modelContext: ModelContext) {
        _viewModel = State(initialValue: KrediKartiDetayViewModel(modelContext: modelContext, kartHesabi: kartHesabi))
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                DonemNavigatorView(
                    baslangicTarihi: viewModel.donemBaslangicTarihi,
                    bitisTarihi: viewModel.donemBitisTarihi,
                    onOnceki: { viewModel.oncekiDonem() },
                    onSonraki: { viewModel.sonrakiDonem() }
                )
                .padding(.bottom, 10)
                
                if viewModel.toplamHarcama > 0 {
                    DonemHarcamaOzetKarti(toplamTutar: viewModel.toplamHarcama)
                        .padding(.horizontal)
                        .padding(.bottom, 10)
                }
                
                List {
                    // Normal Harcamalar Bölümü
                    if !viewModel.donemIslemleri.isEmpty {
                        Section(header: Text(LocalizedStringKey("transfer.section.expenses"))) {
                            ForEach(viewModel.donemIslemleri) { islem in
                                IslemSatirView(
                                    islem: islem,
                                    onEdit: { duzenlenecekIslem = islem },
                                    onDelete: { silmeyiBaslat(islem) }
                                )
                                .id(islem.id) // YENİ: Stabil ID ile re-render'ı optimize et
                            }
                        }
                    }
                    
                    // YENİ: Taksitli Harcamalar Bölümü
                    if !viewModel.taksitliIslemGruplari.isEmpty {
                        Section(header: Text(LocalizedStringKey("credit_card.installment_purchases"))) {
                            ForEach(viewModel.taksitliIslemGruplari) { grup in
                                TaksitliIslemGrubuView(
                                    grup: grup,
                                    isExpanded: expandedGroups.contains(grup.id),
                                    onToggle: { toggleGroup(grup.id) },
                                    onEdit: { taksit in duzenlenecekIslem = taksit },
                                    onDelete: { taksit in silmeyiBaslat(taksit) }
                                )
                                .environmentObject(appSettings)
                                .id(grup.id) // YENİ: Stabil ID ile re-render'ı optimize et
                            }
                        }
                    }
                    
                    // Ödemeler (Transferler) Bölümü
                    if !viewModel.tumTransferler.isEmpty {
                        Section(header: Text(LocalizedStringKey("transfer.section.payments"))) {
                            ForEach(viewModel.tumTransferler) { transfer in
                                TransferSatirView(
                                    transfer: transfer,
                                    hesapID: viewModel.kartHesabi.id
                                )
                                .environmentObject(appSettings)
                                .id(transfer.id) // YENİ: Stabil ID ile re-render'ı optimize et
                            }
                        }
                    }
                    
                    // Hiç işlem yoksa
                    if viewModel.donemIslemleri.isEmpty &&
                       viewModel.taksitliIslemGruplari.isEmpty &&
                       viewModel.tumTransferler.isEmpty {
                        HStack {
                            Spacer()
                            Text(LocalizedStringKey("credit_card_details.no_expenses_for_month"))
                                .foregroundColor(.secondary)
                                .padding()
                            Spacer()
                        }
                    }
                }
                .listStyle(.plain)
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
        .onAppear {
            viewModel.islemleriGetir()
            viewModel.transferleriGetir()
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
                    await TransactionService.shared.deleteSeriesInBackground(
                        tekrarID: islem.tekrarID,
                        from: modelContext.container
                    )
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
            } label: {
                Text("common.delete")
            }
        } message: { islem in
            Text("alert.delete_transaction.message")
        }
        // YENİ: Taksitli işlem silme alert'i
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
    
    private func toggleGroup(_ groupID: UUID) {
        if expandedGroups.contains(groupID) {
            expandedGroups.remove(groupID)
        } else {
            expandedGroups.insert(groupID)
        }
    }
}
