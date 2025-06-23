import SwiftUI
import SwiftData

struct KrediKartiEkleView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appSettings: AppSettings // YENİ: Dil ayarlarına erişim için

    // MARK: - State Properties
    @State private var isim: String = ""
    @State private var limitString: String = ""
    @State private var guncelBorcString: String = "" // Opsiyonel alan
    @State private var kesimTarihi = Date()
    @State private var sonOdemeGunuOfseti: Int = 10 // Varsayılan değer: kesimden 10 gün sonra
    @State private var secilenRenk: Color = .red
    
    var duzenlenecekHesap: Hesap?
    
    @State private var isLimitGecersiz = false
    @State private var isBorcGecersiz = false
    
    // MARK: - Computed Properties
    private var isFormValid: Bool {
        !isim.trimmingCharacters(in: .whitespaces).isEmpty &&
        !limitString.isEmpty &&
        !isLimitGecersiz &&
        !isBorcGecersiz
    }
    
    // --- YENİ EKLENEN YARDIMCI DEĞİŞKEN ---
    // Stepper metnini doğru dilde oluşturan hesaplanmış değişken
    private var stepperLabelText: String {
        let dilKodu = appSettings.languageCode
        
        guard let path = Bundle.main.path(forResource: dilKodu, ofType: "lproj"),
              let languageBundle = Bundle(path: path) else {
            return "\(sonOdemeGunuOfseti)" // Hata durumunda sadece sayıyı göster
        }
        
        let formatString = languageBundle.localizedString(forKey: "credit_card.form.payment_due_date_stepper", value: "%d days after statement date", table: nil)
        
        return String(format: formatString, sonOdemeGunuOfseti)
    }

    // MARK: - Body
    var body: some View {
        NavigationStack {
            Form {
                Section(LocalizedStringKey("transaction.section_details")) {
                    TextField(LocalizedStringKey("accounts.add.card_name_placeholder"), text: $isim)
                    
                    VStack(alignment: .leading) {
                        TextField(LocalizedStringKey("accounts.add.card_limit"), text: $limitString)
                            .keyboardType(.decimalPad)
                            .validateAmountInput(text: $limitString, isInvalid: $isLimitGecersiz)
                            .overlay(RoundedRectangle(cornerRadius: 5).stroke(isLimitGecersiz ? .red : .clear, lineWidth: 1))
                        if isLimitGecersiz {
                            Text(LocalizedStringKey("validation.error.invalid_amount_format"))
                                .font(.caption).foregroundColor(.red).padding(.top, 2)
                        }
                    }
                    
                    VStack(alignment: .leading) {
                        TextField(LocalizedStringKey("credit_card.form.current_debt_optional"), text: $guncelBorcString)
                            .keyboardType(.decimalPad)
                            .validateAmountInput(text: $guncelBorcString, isInvalid: $isBorcGecersiz)
                            .overlay(RoundedRectangle(cornerRadius: 5).stroke(isBorcGecersiz ? .red : .clear, lineWidth: 1))
                        if isBorcGecersiz {
                            Text(LocalizedStringKey("validation.error.invalid_amount_format"))
                                .font(.caption).foregroundColor(.red).padding(.top, 2)
                        }
                    }
                }
                
                Section(header: Text(LocalizedStringKey("credit_card.form.statement_date_header"))) {
                    DatePicker(LocalizedStringKey("credit_card.form.statement_date"), selection: $kesimTarihi, displayedComponents: .date)
                }
                
                Section(header: Text(LocalizedStringKey("credit_card.form.payment_due_date_header"))) {
                    // --- GÜNCELLENEN SATIR ---
                    Stepper(stepperLabelText, value: $sonOdemeGunuOfseti, in: 1...28)
                }
                
                Section(LocalizedStringKey("categories.color")) {
                    ColorPicker(LocalizedStringKey("accounts.add.account_color"), selection: $secilenRenk, supportsOpacity: false)
                }
            }
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
    
    // MARK: - Functions
    private func formuDoldur() {
        guard let hesap = duzenlenecekHesap, case .krediKarti(let limit, let tarih, let ofset) = hesap.detay else { return }
        
        isim = hesap.isim
        limitString = String(format: "%.2f", limit).replacingOccurrences(of: ".", with: ",")
        guncelBorcString = hesap.baslangicBakiyesi != 0 ? String(format: "%.2f", abs(hesap.baslangicBakiyesi)).replacingOccurrences(of: ".", with: ",") : ""
        kesimTarihi = tarih
        sonOdemeGunuOfseti = ofset
        secilenRenk = hesap.renk
    }
    
    private func kaydet() {
        let limit = Double(limitString.replacingOccurrences(of: ",", with: ".")) ?? 0
        let guncelBorc = Double(guncelBorcString.replacingOccurrences(of: ",", with: ".")) ?? 0
        let renkHex = secilenRenk.toHex() ?? "#FF3B30"
        
        let kartDetayi = HesapDetayi.krediKarti(limit: limit, kesimTarihi: kesimTarihi, sonOdemeGunuOfseti: sonOdemeGunuOfseti)
        
        if let hesap = duzenlenecekHesap {
            hesap.isim = isim
            hesap.baslangicBakiyesi = -guncelBorc
            hesap.renkHex = renkHex
            hesap.detay = kartDetayi
        } else {
            let yeniHesap = Hesap(isim: isim, ikonAdi: "creditcard.fill", renkHex: renkHex, baslangicBakiyesi: -guncelBorc, detay: kartDetayi)
            modelContext.insert(yeniHesap)
        }
        dismiss()
    }
}
