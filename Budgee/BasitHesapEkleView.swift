//
//  BasitHesapEkleView.swift
//  Budgee
//
//  Created by Mustafa Turan on 19.06.2025.
//


// Dosya Adı: BasitHesapEkleView.swift

import SwiftUI
import SwiftData

struct BasitHesapEkleView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss

    @State private var isim: String = ""
    @State private var bakiyeString: String = "0"
    @State private var secilenRenk: Color = .blue
    
    // Düzenleme için opsiyonel hesap nesnesi
    var duzenlenecekHesap: Hesap?

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
            .navigationTitle(duzenlenecekHesap == nil ? LocalizedStringKey("accounts.add.wallet") : LocalizedStringKey("common.edit"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(LocalizedStringKey("common.cancel")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("common.save"), action: kaydet)
                        .disabled(isim.isEmpty)
                }
            }
            .onAppear(perform: formuDoldur)
        }
    }
    
    private func formuDoldur() {
        guard let hesap = duzenlenecekHesap else { return }
        isim = hesap.isim
        bakiyeString = String(hesap.baslangicBakiyesi)
        secilenRenk = hesap.renk
    }

    private func kaydet() {
        let bakiye = Double(bakiyeString.replacingOccurrences(of: ",", with: ".")) ?? 0
        let renkHex = secilenRenk.toHex() ?? "#007AFF"
        
        if let hesap = duzenlenecekHesap {
            hesap.isim = isim
            hesap.baslangicBakiyesi = bakiye
            hesap.renkHex = renkHex
        } else {
            let yeniHesap = Hesap(
                isim: isim,
                ikonAdi: "wallet.pass.fill",
                renkHex: renkHex,
                baslangicBakiyesi: bakiye,
                detay: .cuzdan
            )
            modelContext.insert(yeniHesap)
        }
        dismiss()
    }
}