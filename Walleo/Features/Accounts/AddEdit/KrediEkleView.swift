import SwiftUI
import SwiftData
import Combine

struct KrediEkleView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appSettings: AppSettings

    // State değişkenleri aynı kalıyor
    @State private var isim: String = ""
    @State private var cekilenTutarString: String = ""
    @State private var faizOraniString: String = ""
    @State private var faizTipi: FaizTipi = .yillik
    @State private var taksitSayisi: Int = 12
    @State private var ilkTaksitTarihi = Date()
    
    var duzenlenecekHesap: Hesap?

    // body ve diğer fonksiyonların çoğu aynı kalıyor
    var body: some View {
         NavigationStack {
            Form {
                Section(header: Text("loan.form.details_header")) {
                    LabeledTextField(
                        label: "form.label.loan_name",
                        placeholder: "account.name_placeholder_loan",
                        text: $isim
                    )
                    
                    LabeledAmountField(
                        label: "form.label.principal_amount",
                        placeholder: "loan.principal_amount_placeholder",
                        valueString: $cekilenTutarString,
                        isInvalid: .constant(false),
                        locale: Locale(identifier: appSettings.languageCode)
                    )
                    
                    HStack(alignment: .bottom) {
                        LabeledTextField(
                            label: "form.label.interest_rate",
                            placeholder: "loan.interest_rate_placeholder",
                            text: $faizOraniString
                        )
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
                        
                        Picker("loan.form.interest_type", selection: $faizTipi) {
                            ForEach(FaizTipi.allCases, id: \.self) { tip in
                                Text(LocalizedStringKey(tip.localizedKey)).tag(tip)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .padding(.bottom, 8)
                    }
                }
                
                Section(header: Text("accounts.add.installments")) {
                    Stepper(String(format: getLocalized("accounts.add.installments_stepper", from: appSettings), taksitSayisi), value: $taksitSayisi, in: 1...360)
                }
                
                Section(header: Text("loan.form.first_payment_header")) {
                     DatePicker("loan.form.first_installment_date", selection: $ilkTaksitTarihi, displayedComponents: .date)
                }
            }
            .navigationTitle(duzenlenecekHesap == nil ? "accounts.add.new_loan" : "common.edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("common.cancel", action: { dismiss() }) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("accounts.add.create_installments_button", action: kaydet)
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
        // faizOraniString ondalık ayıracına duyarlı olmalı
        faizOraniString = String(oran).replacingOccurrences(of: ".", with: Locale(identifier: appSettings.languageCode).decimalSeparator ?? ".")
        faizTipi = tip
        taksitSayisi = sayi
        ilkTaksitTarihi = tarih
    }
    
    private func kaydet() {
        let locale = Locale(identifier: appSettings.languageCode)
        let cekilenTutar = stringToDouble(cekilenTutarString, locale: locale)
        let faizOrani = stringToDouble(faizOraniString, locale: locale)
        
        // --- GÜNCELLEME BURADA ---
        // `taksitleriHesapla` fonksiyonuna artık faiz tipi de gönderiliyor.
        let taksitler = taksitleriHesapla(
            anapara: cekilenTutar,
            faizOrani: faizOrani,
            faizTipi: faizTipi,
            taksitSayisi: taksitSayisi,
            ilkOdemeTarihi: ilkTaksitTarihi
        )
        
        let krediDetayi = HesapDetayi.kredi(cekilenTutar: cekilenTutar, faizTipi: faizTipi, faizOrani: faizOrani, taksitSayisi: taksitSayisi, ilkTaksitTarihi: ilkTaksitTarihi, taksitler: taksitler)
        
        if let hesap = duzenlenecekHesap {
            hesap.isim = isim
            hesap.baslangicBakiyesi = -cekilenTutar
            hesap.detay = krediDetayi
        } else {
            let yeniHesap = Hesap(isim: isim, ikonAdi: "banknote.fill", renkHex: "#5E5CE6", baslangicBakiyesi: -cekilenTutar, detay: krediDetayi)
            modelContext.insert(yeniHesap)
        }
        
        NotificationCenter.default.post(name: .accountDetailsDidChange, object: nil)

        dismiss()
    }
    
    // --- TAMAMEN YENİLENEN FONKSİYON ---
    private func taksitleriHesapla(anapara P: Double, faizOrani: Double, faizTipi: FaizTipi, taksitSayisi n: Int, ilkOdemeTarihi: Date) -> [KrediTaksitDetayi] {
        guard n > 0, P > 0 else { return [] }
        
        // 1. Adım: Aylık faiz oranını (r) doğru şekilde hesapla
        let aylikFaizOrani_r: Double
        
        if faizTipi == .aylik {
            // Kullanıcı doğrudan aylık faiz girdiyse, 100'e böl.
            aylikFaizOrani_r = faizOrani / 100.0
        } else {
            // Kullanıcı yıllık faiz girdiyse, efektif aylık faizi hesapla.
            let yillikDecimal = faizOrani / 100.0
            aylikFaizOrani_r = pow(1.0 + yillikDecimal, 1.0 / 12.0) - 1.0
        }
        
        // 2. Adım: Annüite formülünü kullanarak taksiti hesapla
        let aylikTaksit: Double
        if aylikFaizOrani_r == 0 {
            // Faiz yoksa, anaparayı ay sayısına böl.
            aylikTaksit = P / Double(n)
        } else {
            let ustelIfade = pow(1 + aylikFaizOrani_r, Double(n))
            aylikTaksit = P * (aylikFaizOrani_r * ustelIfade) / (ustelIfade - 1)
        }
        
        // 3. Adım: Hesaplanan taksiti 2 ondalık basamağa yuvarla
        let yuvarlanmisTaksit = (aylikTaksit * 100).rounded() / 100.0
        
        // 4. Adım: Taksit listesini oluştur
        var taksitListesi: [KrediTaksitDetayi] = []
        let takvim = Calendar.current
        for i in 0..<n {
            if let odemeGunu = takvim.date(byAdding: .month, value: i, to: ilkOdemeTarihi) {
                taksitListesi.append(KrediTaksitDetayi(taksitTutari: yuvarlanmisTaksit, odemeTarihi: odemeGunu))
            }
        }
        return taksitListesi
    }
}
