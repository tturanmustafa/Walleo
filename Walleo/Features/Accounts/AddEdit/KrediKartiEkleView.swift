import SwiftUI
import SwiftData

struct KrediKartiEkleView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appSettings: AppSettings

    @State private var isim: String = ""
    @State private var limitString: String = ""
    @State private var guncelBorcString: String = ""
    @State private var kesimTarihi = Date()
    @State private var sonOdemeGunuOfseti: Int = 10
    @State private var secilenRenk: Color = .red
    
    var duzenlenecekHesap: Hesap?
    
    @State private var isLimitGecersiz = false
    @State private var isBorcGecersiz = false
    
    private var isFormValid: Bool {
        !isim.trimmingCharacters(in: .whitespaces).isEmpty &&
        !limitString.isEmpty &&
        !isLimitGecersiz &&
        !isBorcGecersiz
    }
    
    private var stepperLabelText: String {
        let dilKodu = appSettings.languageCode
        
        guard let path = Bundle.main.path(forResource: dilKodu, ofType: "lproj"),
              let languageBundle = Bundle(path: path) else {
            return "\(sonOdemeGunuOfseti)"
        }
        
        let formatString = languageBundle.localizedString(forKey: "credit_card.form.payment_due_date_stepper", value: "%d days after statement date", table: nil)
        
        return String(format: formatString, sonOdemeGunuOfseti)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(LocalizedStringKey("transaction.section_details"))
                            .font(.caption).foregroundColor(.secondary).padding(.leading)
                        
                        VStack(spacing: 0) {
                            // İSİM ALANI
                            LabeledTextField(
                                label: "form.label.card_name",
                                placeholder: "account.name_placeholder_creditcard",
                                text: $isim
                            )
                            .padding()

                            Divider().padding(.leading)
                            
                            // LİMİT ALANI
                            LabeledAmountField(
                                label: "form.label.card_limit",
                                placeholder: "credit_card.limit_placeholder",
                                valueString: $limitString,
                                isInvalid: $isLimitGecersiz,
                                locale: Locale(identifier: appSettings.languageCode)
                            )
                            .padding()

                            Divider().padding(.leading)
                            
                            // GÜNCEL BORÇ ALANI
                            LabeledAmountField(
                                label: "form.label.current_debt",
                                placeholder: "credit_card.current_debt_placeholder",
                                valueString: $guncelBorcString,
                                isInvalid: $isBorcGecersiz,
                                locale: Locale(identifier: appSettings.languageCode)
                            )
                            .padding()
                        }
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(10)
                    }

                    VStack(alignment: .leading, spacing: 5) {
                         Text(LocalizedStringKey("credit_card.form.statement_date_header"))
                            .font(.caption).foregroundColor(.secondary).padding(.leading)
                        
                        DatePicker(LocalizedStringKey("credit_card.form.statement_date"), selection: $kesimTarihi, displayedComponents: .date)
                            .padding()
                            .background(Color(.secondarySystemGroupedBackground))
                            .cornerRadius(10)
                    }

                    VStack(alignment: .leading, spacing: 5) {
                        Text(LocalizedStringKey("credit_card.form.payment_due_date_header"))
                           .font(.caption).foregroundColor(.secondary).padding(.leading)
                        
                        Stepper(stepperLabelText, value: $sonOdemeGunuOfseti, in: 1...28)
                            .padding()
                            .background(Color(.secondarySystemGroupedBackground))
                            .cornerRadius(10)
                    }
                    
                    VStack(alignment: .leading, spacing: 5) {
                         Text(LocalizedStringKey("categories.color"))
                            .font(.caption).foregroundColor(.secondary).padding(.leading)
                        
                        ColorPicker(LocalizedStringKey("accounts.add.account_color"), selection: $secilenRenk, supportsOpacity: false)
                            .padding()
                            .background(Color(.secondarySystemGroupedBackground))
                            .cornerRadius(10)
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(duzenlenecekHesap == nil ? LocalizedStringKey("accounts.add.new_credit_card") : LocalizedStringKey("common.edit"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(LocalizedStringKey("common.cancel")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("common.save"), action: kaydet).disabled(!isFormValid)
                }
            }
            .onAppear(perform: formuDoldur)
        }
    }
    
    private func formuDoldur() {
        guard let hesap = duzenlenecekHesap, case .krediKarti(let limit, let tarih, let ofset) = hesap.detay else { return }
        
        let localeId = appSettings.languageCode
        isim = hesap.isim
        limitString = formatAmountForEditing(amount: limit, localeIdentifier: localeId)
        guncelBorcString = formatAmountForEditing(amount: abs(hesap.baslangicBakiyesi), localeIdentifier: localeId)
        isLimitGecersiz = false
        isBorcGecersiz = false
        kesimTarihi = tarih
        sonOdemeGunuOfseti = ofset
        secilenRenk = hesap.renk
    }
    
    private func kaydet() {
        let locale = Locale(identifier: appSettings.languageCode)
        let limit = stringToDouble(limitString, locale: locale)
        let guncelBorc = stringToDouble(guncelBorcString, locale: locale)
        let renkHex = secilenRenk.toHex() ?? "#FF3B30"
        
        let kartDetayi = HesapDetayi.krediKarti(limit: limit, kesimTarihi: kesimTarihi, sonOdemeGunuOfseti: sonOdemeGunuOfseti)
        
        if let hesap = duzenlenecekHesap {
            hesap.isim = isim
            hesap.baslangicBakiyesi = -guncelBorc
            hesap.renkHex = renkHex
            hesap.detay = kartDetayi
            
            // --- YENİ SATIRI BURAYA EKLEYİN ---
            // Değişiklik kaydedildi, şimdi sinyali gönder!
            NotificationCenter.default.post(name: .accountDetailsDidChange, object: nil)
            
        } else {
            let yeniHesap = Hesap(isim: isim, ikonAdi: "creditcard.fill", renkHex: renkHex, baslangicBakiyesi: -guncelBorc, detay: kartDetayi)
            modelContext.insert(yeniHesap)
        }
        dismiss()
    }
}
