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
    
    init(hesap: Hesap, modelContext: ModelContext) {
        _viewModel = State(initialValue: KrediDetayViewModel(modelContext: modelContext, hesap: hesap))
    }
    
    var body: some View {
        List {
            krediOzetiSection
            
            Section(LocalizedStringKey("loan_details.installment_plan_header")) {
                ForEach(taksitler) { taksit in
                    HStack(spacing: 16) {
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
                                Label(LocalizedStringKey("installment.paid.label"), systemImage: "checkmark")
                            }
                            .tint(.green)
                        }
                    }
                }
            }
        }
        .sheet(item: $duzenlenecekTaksitID) { taksitID in
            TaksitDuzenleView(hesap: viewModel.hesap, taksitID: taksitID)
        }
        .alert(LocalizedStringKey("alert.add_as_expense.title"), isPresented: $viewModel.giderEkleUyarisiGoster, presenting: viewModel.islemOlusturulacakTaksit) { taksit in
            Button(LocalizedStringKey("alert.add_as_expense.button_yes"), role: .destructive) { viewModel.taksidiOnaylaVeGiderEkle(onayla: true) }
            Button(LocalizedStringKey("alert.add_as_expense.button_no")) { viewModel.taksidiOnaylaVeGiderEkle(onayla: false) }
            Button(LocalizedStringKey("common.cancel"), role: .cancel) { }
        } message: { taksit in
            let dilKodu = appSettings.languageCode
            
            guard let path = Bundle.main.path(forResource: dilKodu, ofType: "lproj"),
                  let languageBundle = Bundle(path: path) else {
                return Text("Error creating message.")
            }
            
            let formatString = languageBundle.localizedString(forKey: "alert.add_as_expense.message_format", value: "", table: nil)
            let tutarString = formatCurrency(amount: taksit.taksitTutari, currencyCode: appSettings.currencyCode, localeIdentifier: appSettings.languageCode)
            
            // --- DÜZELTME BURADA ---
            // Closure içinde birden fazla satır olduğu için 'return' ifadesi eklenmelidir.
            return Text(String(format: formatString, tutarString))
        }
        .navigationTitle(viewModel.hesap.isim)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var krediOzetiSection: some View {
        Section(LocalizedStringKey("loan_details.summary_header")) {
            // DÜZELTME 1: Çekilen Tutar etiket sorunu çözüldü.
            if case .kredi(let cekilenTutar, let faizTipi, let faizOrani, let taksitSayisi, _, _) = viewModel.hesap.detay {
                HStack {
                    // Text artık LocalizedStringKey alıyor.
                    Text(LocalizedStringKey("accounts.add.loan_amount"))
                    Spacer()
                    Text(formatCurrency(amount: cekilenTutar, currencyCode: appSettings.currencyCode, localeIdentifier: appSettings.languageCode))
                }
                
                // DÜZELTME 2: Faiz Oranı değeri ve etiketi sorunu çözüldü.
                HStack {
                    Text(LocalizedStringKey("accounts.add.interest_rate")) // Bu anahtarın değerini "Faiz Oranı (%)" olarak güncelledik.
                    Spacer()
                    // Değer artık faiz tipine göre dinamik ve lokalize.
                    Text("\(NSLocalizedString(faizTipi.localizedKey, comment: "")) %\(String(format: "%.2f", faizOrani))")
                }
                
                HStack {
                    Text(LocalizedStringKey("accounts.add.installments"))
                    Spacer()
                    // Bu satır zaten doğru çalışıyordu, tutarlılık için kontrol edildi.
                    Text(String.localizedStringWithFormat(NSLocalizedString("accounts.add.installments_stepper", comment: ""), taksitSayisi))
                }
            }
        }
    }
}
