// Dosya Adı: KrediKartiEkleView.swift (NİHAİ - HANE KONTROLLÜ)

import SwiftUI
import SwiftData

struct KrediKartiEkleView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss

    @State private var isim: String = ""
    @State private var limitString: String = ""
    @State private var guncelBorcString: String = "" // Opsiyonel alan
    @State private var kesimTarihi = Date()
    @State private var secilenRenk: Color = .red
    var duzenlenecekHesap: Hesap?
    
    // YENİ: Her alan için ayrı doğrulama durumları
    @State private var isLimitGecersiz = false
    @State private var isBorcGecersiz = false
    
    // GÜNCELLENDİ: Formun geçerliliği tüm alanları kontrol ediyor
    private var isFormValid: Bool {
        !isim.trimmingCharacters(in: .whitespaces).isEmpty &&
        !limitString.isEmpty &&
        !isLimitGecersiz &&
        !isBorcGecersiz
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(LocalizedStringKey("transaction.section_details")) {
                    TextField(LocalizedStringKey("accounts.add.card_name_placeholder"), text: $isim)
                    
                    VStack(alignment: .leading) {
                        TextField(LocalizedStringKey("accounts.add.card_limit"), text: $limitString)
                            .keyboardType(.decimalPad)
                            .onChange(of: limitString) { haneKontrolluDogrula(newValue: $0, tur: .limit) }
                            .overlay(RoundedRectangle(cornerRadius: 5).stroke(isLimitGecersiz ? .red : .clear, lineWidth: 1))
                        if isLimitGecersiz {
                            Text(LocalizedStringKey("validation.error.invalid_amount_format"))
                                .font(.caption).foregroundColor(.red).padding(.top, 2)
                        }
                    }
                    
                    VStack(alignment: .leading) {
                        TextField(LocalizedStringKey("credit_card.form.current_debt_optional"), text: $guncelBorcString)
                            .keyboardType(.decimalPad)
                            .onChange(of: guncelBorcString) { haneKontrolluDogrula(newValue: $0, tur: .borc) }
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
    
    // YENİ: Hangi alanın doğrulandığını ayırt etmek için enum
    enum AlanTuru { case limit, borc }
    private func haneKontrolluDogrula(newValue: String, tur: AlanTuru) {
        // Hangi state değişkeninin güncelleneceğini belirle
        let isInvalidFlag: (Bool) -> Void = { tur == .limit ? (isLimitGecersiz = $0) : (isBorcGecersiz = $0) }
        
        if newValue.isEmpty { isInvalidFlag(false); return }
        
        let normalizedString = newValue.replacingOccurrences(of: ",", with: ".")
        guard normalizedString.components(separatedBy: ".").count <= 2, Double(normalizedString) != nil else { isInvalidFlag(true); return }
        
        let parts = normalizedString.components(separatedBy: ".")
        if parts[0].count > 9 { isInvalidFlag(true); return }
        if parts.count == 2 && parts[1].count > 2 { isInvalidFlag(true); return }
        
        isInvalidFlag(false)
    }
    
    private func formuDoldur() {
        guard let hesap = duzenlenecekHesap, case .krediKarti(let limit, let tarih) = hesap.detay else { return }
        isim = hesap.isim
        limitString = String(format: "%.2f", limit).replacingOccurrences(of: ".", with: ",")
        guncelBorcString = hesap.baslangicBakiyesi != 0 ? String(format: "%.2f", abs(hesap.baslangicBakiyesi)).replacingOccurrences(of: ".", with: ",") : ""
        
        // GÜNCELLENDİ: Düzenleme modunda her iki alan için de doğrulama yapılır.
        haneKontrolluDogrula(newValue: limitString, tur: .limit)
        haneKontrolluDogrula(newValue: guncelBorcString, tur: .borc)
        
        kesimTarihi = tarih
        secilenRenk = hesap.renk
    }
    
    private func kaydet() {
        let limit = Double(limitString.replacingOccurrences(of: ",", with: ".")) ?? 0
        let guncelBorc = Double(guncelBorcString.replacingOccurrences(of: ",", with: ".")) ?? 0
        let renkHex = secilenRenk.toHex() ?? "#FF3B30"
        let kartDetayi = HesapDetayi.krediKarti(limit: limit, kesimTarihi: kesimTarihi)
        
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
