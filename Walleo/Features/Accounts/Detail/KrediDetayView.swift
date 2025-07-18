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
                                    viewModel.taksidiOdemeyiBaslat(taksit: taksit)
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
                                viewModel.taksidiOdemeyiBaslat(taksit: taksit)
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
        // YENİ SHEET: Hesap seçim ekranını gösterir
        .sheet(isPresented: $viewModel.hesapSecimSayfasiniGoster) {
            HesapSecimView(odemeHesaplari: viewModel.odemeHesaplari) { secilenHesap in
                viewModel.giderIsleminiOlustur(hesap: secilenHesap)
            }
            .presentationDetents([.medium])

        }
        // GÜNCELLENMİŞ ALERT: "Gider olarak ekle" uyarısı
        .alert(LocalizedStringKey("alert.add_as_expense.title"), isPresented: $viewModel.giderEkleUyarisiGoster) {
            Button(LocalizedStringKey("alert.add_as_expense.button_yes"), role: .destructive) {
                viewModel.giderOlarakEklemeyiOnayla()
            }
            Button(LocalizedStringKey("alert.add_as_expense.button_no")) {
                viewModel.sadeceOdenmisIsaretle()
            }
            Button(LocalizedStringKey("common.cancel"), role: .cancel) { }
        } message: {
            let dilKodu = appSettings.languageCode
            guard let path = Bundle.main.path(forResource: dilKodu, ofType: "lproj"),
                  let languageBundle = Bundle(path: path) else {
                return Text("Error creating message.") // Hata durumu
            }
            let formatString = languageBundle.localizedString(forKey: "alert.add_as_expense.message_format", value: "", table: nil)
            let tutarString = formatCurrency(amount: viewModel.islemYapilacakTaksit?.taksitTutari ?? 0, currencyCode: appSettings.currencyCode, localeIdentifier: appSettings.languageCode)
            
            return Text(String(format: formatString, tutarString))
        }
        // YENİ ALERT: Uygun hesap bulunamadı uyarısı
        .alert(LocalizedStringKey("alert.no_payment_account.title"), isPresented: $viewModel.uygunHesapYokUyarisiGoster) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(LocalizedStringKey("alert.no_payment_account.message"))
        }
        .navigationTitle(viewModel.hesap.isim)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var krediOzetiSection: some View {
        Section(LocalizedStringKey("loan_details.summary_header")) {
            if case .kredi(let cekilenTutar, let faizTipi, let faizOrani, let taksitSayisi, _, _) = viewModel.hesap.detay {
                
                HStack {
                    Text(LocalizedStringKey("accounts.add.loan_amount"))
                    Spacer()
                    Text(formatCurrency(amount: cekilenTutar, currencyCode: appSettings.currencyCode, localeIdentifier: appSettings.languageCode))
                }
                
                // DÜZELTME: Artık yeni merkezi fonksiyonumuzu kullanıyor.
                HStack {
                    Text(LocalizedStringKey("accounts.add.interest_rate"))
                    Spacer()
                    Text("\(getLocalized(faizTipi.localizedKey, from: appSettings)) %\(String(format: "%.2f", faizOrani))")
                }
                
                // DÜZELTME: Artık yeni merkezi fonksiyonumuzu kullanıyor.
                HStack {
                    Text(LocalizedStringKey("accounts.add.installments"))
                    Spacer()
                    Text(String(format: getLocalized("accounts.add.installments_stepper", from: appSettings), taksitSayisi))
                }
            }
        }
    }
}
