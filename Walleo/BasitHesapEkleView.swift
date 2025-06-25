// Dosya Adı: BasitHesapEkleView.swift

import SwiftUI
import SwiftData

struct BasitHesapEkleView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss

    @State private var isim: String = ""
    @State private var bakiyeString: String = "0"
    @State private var secilenRenk: Color = .blue
    var duzenlenecekHesap: Hesap?
    
    @State private var isBakiyeGecersiz = false
    
    private var isFormValid: Bool {
        !isim.trimmingCharacters(in: .whitespaces).isEmpty && !isBakiyeGecersiz
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(LocalizedStringKey("transaction.section_details")) {
                    TextField(LocalizedStringKey("accounts.add.account_name_placeholder"), text: $isim)
                    
                    VStack(alignment: .leading) {
                        FormattedAmountField(
                            "accounts.add.initial_balance",
                            value: $bakiyeString,
                            isInvalid: $isBakiyeGecersiz
                        )
                            .overlay(RoundedRectangle(cornerRadius: 5).stroke(isBakiyeGecersiz ? Color.red : Color.clear, lineWidth: 1))
                        
                        if isBakiyeGecersiz {
                            Text(LocalizedStringKey("validation.error.invalid_amount_format"))
                                .font(.caption).foregroundColor(.red).padding(.top, 2)
                        }
                    }
                }
                Section(LocalizedStringKey("categories.color")) {
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
    
    private func haneKontrolluDogrula(newValue: String) {
        if newValue.isEmpty { isBakiyeGecersiz = false; return }
        let normalizedString = newValue.replacingOccurrences(of: ",", with: ".")
        guard normalizedString.components(separatedBy: ".").count <= 2, Double(normalizedString) != nil else { isBakiyeGecersiz = true; return }
        let parts = normalizedString.components(separatedBy: ".")
        if parts[0].count > 9 { isBakiyeGecersiz = true; return }
        if parts.count == 2 && parts[1].count > 2 { isBakiyeGecersiz = true; return }
        isBakiyeGecersiz = false
    }
    
    private func formuDoldur() {
        guard let hesap = duzenlenecekHesap else { return }
        isim = hesap.isim
        bakiyeString = String(format: "%.2f", hesap.baslangicBakiyesi).replacingOccurrences(of: ".", with: ",")
        haneKontrolluDogrula(newValue: bakiyeString)
        secilenRenk = hesap.renk
    }

    private func kaydet() {
        let bakiye = Double(bakiyeString.replacingOccurrences(of: ",", with: ".")) ?? 0
        let renkHex = secilenRenk.toHex() ?? "#007AFF"
        if let hesap = duzenlenecekHesap {
            hesap.isim = isim; hesap.baslangicBakiyesi = bakiye; hesap.renkHex = renkHex
        } else {
            let yeniHesap = Hesap(isim: isim, ikonAdi: "wallet.pass.fill", renkHex: renkHex, baslangicBakiyesi: bakiye, detay: .cuzdan)
            modelContext.insert(yeniHesap)
        }
        dismiss()
    }
}
