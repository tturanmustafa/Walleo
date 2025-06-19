//
//  CuzdanEkleView.swift
//  Budgee
//
//  Created by Mustafa Turan on 19.06.2025.
//


// Dosya Adı: CuzdanEkleView.swift (Yeni veya güncellenmiş)

import SwiftUI

struct CuzdanEkleView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss

    @State private var isim: String = ""
    @State private var bakiyeString: String = "0"
    @State private var secilenRenk: Color = .blue

    var body: some View {
        NavigationStack {
            Form {
                Section(LocalizedStringKey("transaction.section_details")) {
                    TextField(LocalizedStringKey("accounts.add.account_name_placeholder"), text: $isim)
                    TextField(LocalizedStringKey("accounts.add.initial_balance"), text: $bakiyeString)
                        .keyboardType(.decimalPad)
                }
                Section(LocalizedStringKey("categories.color")) {
                    ColorPicker(LocalizedStringKey("accounts.add.account_color"), selection: $secilenRenk, supportsOpacity: false)
                }
            }
            .navigationTitle(LocalizedStringKey("accounts.add.wallet"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(LocalizedStringKey("common.cancel")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("common.save"), action: kaydet)
                        .disabled(isim.isEmpty)
                }
            }
        }
    }

    private func kaydet() {
        let bakiye = Double(bakiyeString.replacingOccurrences(of: ",", with: ".")) ?? 0
        let renkHex = secilenRenk.toHex() ?? "#007AFF"
        
        let yeniHesap = Hesap(
            isim: isim,
            ikonAdi: "wallet.pass.fill",
            renkHex: renkHex,
            baslangicBakiyesi: bakiye,
            detay: .cuzdan
        )
        modelContext.insert(yeniHesap)
        dismiss()
    }
}