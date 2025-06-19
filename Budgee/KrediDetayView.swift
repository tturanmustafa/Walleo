// Dosya Adı: KrediDetayView.swift

import SwiftUI
import SwiftData

struct KrediDetayView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appSettings: AppSettings
    @State private var viewModel: KrediDetayViewModel
    
    @State private var duzenlenecekTaksitID: UUID?
    
    private var taksitler: [KrediTaksitDetayi] {
        if case .kredi(_, _, _, _, _, let taksitler) = viewModel.hesap.detay {
            return taksitler.sorted(by: { $0.odemeTarihi < $1.odemeTarihi })
        }
        return []
    }
    
    init(hesap: Hesap) {
        let container = try! ModelContainer(for: Hesap.self, Islem.self, Kategori.self)
        _viewModel = State(initialValue: KrediDetayViewModel(modelContext: container.mainContext, hesap: hesap))
    }
    
    var body: some View {
        List {
            krediOzetiSection
            
            Section("Taksit Planı") {
                ForEach(taksitler) { taksit in
                    HStack(spacing: 16) {
                        // --- DÜZELTME 1: 'Button' yerine 'Image' ve '.onTapGesture' ---
                        Image(systemName: taksit.odendiMi ? "checkmark.circle.fill" : "circle")
                            .font(.title2)
                            .foregroundColor(taksit.odendiMi ? .green : .accentColor)
                            .onTapGesture {
                                if !taksit.odendiMi {
                                    viewModel.taksidiOde(taksit: taksit)
                                }
                            }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(taksit.odemeTarihi, style: .date)
                                .foregroundStyle(taksit.odendiMi ? .secondary : .primary)
                            Text(formatCurrency(amount: taksit.taksitTutari, currencyCode: appSettings.currencyCode, localeIdentifier: appSettings.languageCode))
                                .font(.headline.bold())
                                .foregroundStyle(taksit.odendiMi ? .secondary : .primary)
                        }
                        
                        Spacer()
                        
                        // --- DÜZELTME 2: 'Button' yerine 'Image' ve '.onTapGesture' ---
                        Image(systemName: "pencil")
                            .foregroundColor(taksit.odendiMi ? .secondary.opacity(0.5) : .accentColor)
                            .onTapGesture {
                                if !taksit.odendiMi {
                                    duzenlenecekTaksitID = taksit.id
                                }
                            }
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        if !taksit.odendiMi {
                            Button {
                                viewModel.taksidiOde(taksit: taksit)
                            } label: {
                                Label("Ödendi İşaretle", systemImage: "checkmark")
                            }
                            .tint(.green)
                        }
                    }
                }
            }
        }
        .task {
            viewModel.modelContext = self.modelContext
        }
        .sheet(item: $duzenlenecekTaksitID) { taksitID in
            TaksitDuzenleView(hesap: viewModel.hesap, taksitID: taksitID)
        }
        .alert(LocalizedStringKey("alert.add_as_expense.title"), isPresented: $viewModel.giderEkleUyarisiGoster, presenting: viewModel.islemOlusturulacakTaksit) { taksit in
            Button(LocalizedStringKey("alert.add_as_expense.button_yes"), role: .destructive) { viewModel.taksidiOnaylaVeGiderEkle(onayla: true) }
            Button(LocalizedStringKey("alert.add_as_expense.button_no")) { viewModel.taksidiOnaylaVeGiderEkle(onayla: false) }
            Button(LocalizedStringKey("common.cancel"), role: .cancel) { }
        } message: { taksit in
            // Lokalize edilmiş formatı kullanarak mesajı oluşturuyoruz
            let tutarString = formatCurrency(amount: taksit.taksitTutari, currencyCode: appSettings.currencyCode, localeIdentifier: appSettings.languageCode)
            let formatString = NSLocalizedString("alert.add_as_expense.message_format", comment: "")
            Text(String(format: formatString, tutarString))
        }
        .navigationTitle(viewModel.hesap.isim)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var krediOzetiSection: some View {
        Section("Kredi Özeti") {
            if case .kredi(let cekilenTutar, let faizTipi, let faizOrani, let taksitSayisi, _, _) = viewModel.hesap.detay {
                HStack { Text(LocalizedStringKey("accounts.add.loan_amount")); Spacer(); Text(formatCurrency(amount: cekilenTutar, currencyCode: appSettings.currencyCode, localeIdentifier: appSettings.languageCode)) }
                HStack { Text(LocalizedStringKey("accounts.add.interest_rate")); Spacer(); Text("\(faizTipi.rawValue) %\(String(format: "%.2f", faizOrani))") }
                HStack { Text(LocalizedStringKey("accounts.add.installments")); Spacer(); Text("\(taksitSayisi) Ay") }
            }
        }
    }
}
