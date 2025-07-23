import SwiftUI
import SwiftData
import Combine

// KrediEkleView.swift dosyasında yapılacak değişiklikler:

struct KrediEkleView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appSettings: AppSettings

    // State değişkenleri
    @State private var isim: String = ""
    @State private var cekilenTutarString: String = ""
    @State private var faizOraniString: String = ""
    @State private var faizTipi: FaizTipi = .yillik
    @State private var taksitSayisi: Int = 12
    @State private var ilkTaksitTarihi = Date()
    
    // YENİ: Renk seçimi için state
    @State private var secilenRenk: Color = .purple
    
    var duzenlenecekHesap: Hesap?

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("loan.form.details_header")) {
                    // Mevcut form alanları aynı kalacak
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
                
                // YENİ: Renk seçimi bölümü
                Section(header: Text(LocalizedStringKey("categories.color"))) {
                    ColorPicker(LocalizedStringKey("accounts.add.account_color"), selection: $secilenRenk, supportsOpacity: false)
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
        faizOraniString = String(oran).replacingOccurrences(of: ".", with: Locale(identifier: appSettings.languageCode).decimalSeparator ?? ".")
        faizTipi = tip
        taksitSayisi = sayi
        ilkTaksitTarihi = tarih
        // YENİ: Mevcut rengi yükle
        secilenRenk = hesap.renk
    }
    
    private func kaydet() {
        let locale = Locale(identifier: appSettings.languageCode)
        let cekilenTutar = stringToDouble(cekilenTutarString, locale: locale)
        let faizOrani = stringToDouble(faizOraniString, locale: locale)
        
        // YENİ: Seçilen rengi hex'e çevir
        let renkHex = secilenRenk.toHex() ?? "#5E5CE6"
        
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
            // YENİ: Rengi güncelle
            hesap.renkHex = renkHex
            hesap.detay = krediDetayi
        } else {
            // YENİ: Yeni hesap oluştururken seçilen rengi kullan
            let yeniHesap = Hesap(isim: isim, ikonAdi: "banknote.fill", renkHex: renkHex, baslangicBakiyesi: -cekilenTutar, detay: krediDetayi)
            modelContext.insert(yeniHesap)
        }
        
        NotificationCenter.default.post(name: .accountDetailsDidChange, object: nil)
        dismiss()
    }
    
    // taksitleriHesapla fonksiyonu aynı kalacak
    private func taksitleriHesapla(anapara P: Double, faizOrani: Double, faizTipi: FaizTipi, taksitSayisi n: Int, ilkOdemeTarihi: Date) -> [KrediTaksitDetayi] {
        // Mevcut implementasyon aynı kalacak
        guard n > 0, P > 0 else { return [] }
        
        let aylikFaizOrani_r: Double
        
        if faizTipi == .aylik {
            aylikFaizOrani_r = faizOrani / 100.0
        } else {
            let yillikDecimal = faizOrani / 100.0
            aylikFaizOrani_r = pow(1.0 + yillikDecimal, 1.0 / 12.0) - 1.0
        }
        
        let aylikTaksit: Double
        if aylikFaizOrani_r == 0 {
            aylikTaksit = P / Double(n)
        } else {
            let ustelIfade = pow(1 + aylikFaizOrani_r, Double(n))
            aylikTaksit = P * (aylikFaizOrani_r * ustelIfade) / (ustelIfade - 1)
        }
        
        let yuvarlanmisTaksit = (aylikTaksit * 100).rounded() / 100.0
        
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
