// YENİ DOSYA: BasitHesapEkleView.swift

import SwiftUI
import SwiftData

struct BasitHesapEkleView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appSettings: AppSettings

    @State private var isim: String = ""
    @State private var baslangicBakiyesiString: String = ""
    @State private var secilenRenk: Color = .green
    
    var duzenlenecekHesap: Hesap?
    
    @State private var isBakiyeGecersiz = false
    
    private var isFormValid: Bool {
        !isim.trimmingCharacters(in: .whitespaces).isEmpty && !isBakiyeGecersiz
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text(LocalizedStringKey("transaction.section_details"))) {
                    LabeledTextField(
                        label: "form.label.wallet_name",
                        placeholder: "account.name_placeholder_wallet", // Açıklayıcı, eski anahtar
                        text: $isim
                    )
                    
                    LabeledAmountField(
                        label: "form.label.initial_balance",
                        placeholder: "account.initial_balance_placeholder", // Açıklayıcı, eski anahtar
                        valueString: $baslangicBakiyesiString,
                        isInvalid: $isBakiyeGecersiz,
                        locale: Locale(identifier: appSettings.languageCode)
                    )
                }
                
                Section(header: Text(LocalizedStringKey("categories.color"))) {
                    ColorPicker(LocalizedStringKey("accounts.add.account_color"), selection: $secilenRenk, supportsOpacity: false)
                }
            }
            .navigationTitle(duzenlenecekHesap == nil ? LocalizedStringKey("accounts.add.wallet") : LocalizedStringKey("common.edit"))
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
        guard let hesap = duzenlenecekHesap else { return }
        
        isim = hesap.isim
        baslangicBakiyesiString = formatAmountForEditing(amount: hesap.baslangicBakiyesi, localeIdentifier: appSettings.languageCode)
        isBakiyeGecersiz = false
        secilenRenk = hesap.renk
    }
    
    private func kaydet() {
        let locale = Locale(identifier: appSettings.languageCode)
        let baslangicBakiyesi = stringToDouble(baslangicBakiyesiString, locale: locale)
        let renkHex = secilenRenk.toHex() ?? "#34C759"
        
        if let hesap = duzenlenecekHesap {
            hesap.isim = isim
            hesap.baslangicBakiyesi = baslangicBakiyesi
            hesap.renkHex = renkHex
        } else {
            let yeniHesap = Hesap(
                isim: isim,
                ikonAdi: "wallet.pass.fill",
                renkHex: renkHex,
                baslangicBakiyesi: baslangicBakiyesi,
                detay: .cuzdan
            )
            modelContext.insert(yeniHesap)
        }
        dismiss()
    }
}
