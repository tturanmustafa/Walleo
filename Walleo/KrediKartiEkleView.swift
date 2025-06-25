import SwiftUI
import SwiftData

struct KrediKartiEkleView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appSettings: AppSettings

    // MARK: - State Properties
    @State private var isim: String = ""
    @State private var limitString: String = ""
    @State private var guncelBorcString: String = "" // Opsiyonel alan
    @State private var kesimTarihi = Date()
    @State private var sonOdemeGunuOfseti: Int = 10
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
    
    private var stepperLabelText: String {
        let dilKodu = appSettings.languageCode
        
        guard let path = Bundle.main.path(forResource: dilKodu, ofType: "lproj"),
              let languageBundle = Bundle(path: path) else {
            return "\(sonOdemeGunuOfseti)"
        }
        
        let formatString = languageBundle.localizedString(forKey: "credit_card.form.payment_due_date_stepper", value: "%d days after statement date", table: nil)
        
        return String(format: formatString, sonOdemeGunuOfseti)
    }

    // MARK: - Body
    var body: some View {
        NavigationStack {
            // --- DÜZELTME: 'Form' yerine 'ScrollView' ve 'VStack' kullanıyoruz ---
            ScrollView {
                VStack(spacing: 20) {
                    // Detaylar Bölümü
                    VStack(alignment: .leading, spacing: 5) {
                        Text(LocalizedStringKey("transaction.section_details"))
                            .font(.caption).foregroundColor(.secondary).padding(.leading)
                        
                        VStack(spacing: 0) {
                            TextField(LocalizedStringKey("accounts.add.card_name_placeholder"), text: $isim).padding()
                            Divider().padding(.leading)
                            
                            // Limit TextField
                            VStack(alignment: .leading) {
                                FormattedAmountField(
                                    "accounts.add.card_limit",
                                    value: $limitString,
                                    isInvalid: $isLimitGecersiz
                                )
                                if isLimitGecersiz {
                                    Text(LocalizedStringKey("validation.error.invalid_amount_format"))
                                        .font(.caption).foregroundColor(.red).padding(.top, 2)
                                }
                            }.padding()
                            
                            Divider().padding(.leading)
                            
                            // Güncel Borç TextField
                            VStack(alignment: .leading) {
                                FormattedAmountField(
                                    "credit_card.form.current_debt_optional",
                                    value: $guncelBorcString,
                                    isInvalid: $isBorcGecersiz
                                )
                                if isBorcGecersiz {
                                    Text(LocalizedStringKey("validation.error.invalid_amount_format"))
                                        .font(.caption).foregroundColor(.red).padding(.top, 2)
                                }
                            }.padding()
                        }
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(10)
                    }

                    // Hesap Kesim Tarihi Bölümü
                    VStack(alignment: .leading, spacing: 5) {
                         Text(LocalizedStringKey("credit_card.form.statement_date_header"))
                            .font(.caption).foregroundColor(.secondary).padding(.leading)
                        
                        DatePicker(LocalizedStringKey("credit_card.form.statement_date"), selection: $kesimTarihi, displayedComponents: .date)
                            .padding()
                            .background(Color(.secondarySystemGroupedBackground))
                            .cornerRadius(10)
                    }

                    // Son Ödeme Günü Bölümü
                    VStack(alignment: .leading, spacing: 5) {
                        Text(LocalizedStringKey("credit_card.form.payment_due_date_header"))
                           .font(.caption).foregroundColor(.secondary).padding(.leading)
                        
                        Stepper(stepperLabelText, value: $sonOdemeGunuOfseti, in: 1...28)
                            .padding()
                            .background(Color(.secondarySystemGroupedBackground))
                            .cornerRadius(10)
                    }
                    
                    // Renk Seçimi Bölümü
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
    
    // MARK: - Functions (Aynı kalıyor)
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
