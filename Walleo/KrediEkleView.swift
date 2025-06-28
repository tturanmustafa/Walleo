import SwiftUI
import SwiftData
import Combine

struct KrediEkleView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appSettings: AppSettings

    @State private var isim: String = ""
    @State private var cekilenTutarString: String = ""
    @State private var faizOraniString: String = ""
    @State private var faizTipi: FaizTipi = .yillik
    @State private var taksitSayisi: Int = 12
    @State private var ilkTaksitTarihi = Date()
    
    var duzenlenecekHesap: Hesap?

    var body: some View {
         NavigationStack {
            Form {
                Section(header: Text(LocalizedStringKey("loan.form.details_header"))) {
                    // DÜZELTME: Placeholder özelleştirildi.
                    TextField(LocalizedStringKey("account.name_placeholder_loan"), text: $isim)
                    
                    // DÜZELTME: Placeholder özelleştirildi.
                    FormattedAmountField(
                        "loan.principal_amount_placeholder",
                        value: $cekilenTutarString,
                        isInvalid: .constant(false),
                        locale: Locale(identifier: appSettings.languageCode)
                    )
                    
                    HStack {
                        // DÜZELTME: Placeholder özelleştirildi.
                        TextField(LocalizedStringKey("loan.interest_rate_placeholder"), text: $faizOraniString)
                            .keyboardType(.decimalPad)
                            .onChange(of: faizOraniString) {
                                let decimalSeparator = Locale(identifier: appSettings.languageCode).decimalSeparator ?? "."
                                var filtered = faizOraniString.filter { "0123456789".contains($0) || String($0) == decimalSeparator }
                                let parts = filtered.components(separatedBy: decimalSeparator)
                                if parts.count > 2 {
                                    filtered = parts[0] + decimalSeparator + parts.dropFirst().joined()
                                }
                                if filtered != faizOraniString {
                                    faizOraniString = filtered
                                }
                            }
                        
                        Picker(LocalizedStringKey("loan.form.interest_type"), selection: $faizTipi) {
                            ForEach(FaizTipi.allCases, id: \.self) { tip in
                                Text(LocalizedStringKey(tip.localizedKey)).tag(tip)
                            }
                        }.pickerStyle(.menu).labelsHidden()
                    }
                }
                
                Section(header: Text(LocalizedStringKey("accounts.add.installments"))) {
                    // DÜZELTME 3: Stepper metni artık lokalize.
                    Stepper(String.localizedStringWithFormat(NSLocalizedString("accounts.add.installments_stepper", comment: ""), taksitSayisi), value: $taksitSayisi, in: 1...360)
                }
                
                Section(header: Text(LocalizedStringKey("loan.form.first_payment_header"))) {
                     DatePicker(LocalizedStringKey("loan.form.first_installment_date"), selection: $ilkTaksitTarihi, displayedComponents: .date)
                }
            }
            .navigationTitle(duzenlenecekHesap == nil ? LocalizedStringKey("accounts.add.new_loan") : LocalizedStringKey("common.edit"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(LocalizedStringKey("common.cancel"), action: { dismiss() }) }
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("accounts.add.create_installments_button"), action: kaydet)
                        .disabled(isim.isEmpty || cekilenTutarString.isEmpty)
                }
            }
            .onAppear(perform: formuDoldur)
        }
    }
    
    private func formuDoldur() {
        guard let hesap = duzenlenecekHesap, case .kredi(let tutar, let tip, let oran, let sayi, let tarih, _) = hesap.detay else { return }
        isim = hesap.isim
        cekilenTutarString = formatAmountForEditing(amount: tutar, localeIdentifier: appSettings.languageCode)
        faizOraniString = String(oran)
        faizTipi = tip
        taksitSayisi = sayi
        ilkTaksitTarihi = tarih
    }
    
    private func kaydet() {
        let locale = Locale(identifier: appSettings.languageCode)
        let cekilenTutar = stringToDouble(cekilenTutarString, locale: locale)
        let faizOrani = stringToDouble(faizOraniString, locale: locale)
        
        let taksitler = taksitleriHesapla(anapara: cekilenTutar, yillikFaizYuzdesi: faizTipi == .yillik ? faizOrani : faizOrani * 12, taksitSayisi: taksitSayisi, ilkOdemeTarihi: ilkTaksitTarihi)
        
        let krediDetayi = HesapDetayi.kredi(cekilenTutar: cekilenTutar, faizTipi: faizTipi, faizOrani: faizOrani, taksitSayisi: taksitSayisi, ilkTaksitTarihi: ilkTaksitTarihi, taksitler: taksitler)
        
        if let hesap = duzenlenecekHesap {
            hesap.isim = isim
            hesap.baslangicBakiyesi = -cekilenTutar
            hesap.detay = krediDetayi
        } else {
            let yeniHesap = Hesap(isim: isim, ikonAdi: "banknote.fill", renkHex: "#5E5CE6", baslangicBakiyesi: -cekilenTutar, detay: krediDetayi)
            modelContext.insert(yeniHesap)
        }
        dismiss()
    }
    
    private func taksitleriHesapla(anapara P: Double, yillikFaizYuzdesi: Double, taksitSayisi n: Int, ilkOdemeTarihi: Date) -> [KrediTaksitDetayi] {
        guard n > 0, P > 0 else { return [] }
        let aylikFaizOrani_r = (yillikFaizYuzdesi / 100) / 12
        let aylikTaksit: Double = aylikFaizOrani_r == 0 ? (P / Double(n)) : (P * (aylikFaizOrani_r * pow(1 + aylikFaizOrani_r, Double(n))) / (pow(1 + aylikFaizOrani_r, Double(n)) - 1))
        var taksitListesi: [KrediTaksitDetayi] = []
        let takvim = Calendar.current
        for i in 0..<n {
            if let odemeGunu = takvim.date(byAdding: .month, value: i, to: ilkOdemeTarihi) {
                taksitListesi.append(KrediTaksitDetayi(taksitTutari: aylikTaksit, odemeTarihi: odemeGunu))
            }
        }
        return taksitListesi
    }
}
