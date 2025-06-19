//
//  KrediKartiEkleView.swift
//  Budgee
//
//  Created by Mustafa Turan on 19.06.2025.
//


// Dosya Adı: KrediKartiEkleView.swift

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

    var body: some View {
        NavigationStack {
            Form {
                Section(LocalizedStringKey("transaction.section_details")) {
                    TextField(LocalizedStringKey("accounts.add.card_name_placeholder"), text: $isim)
                    TextField(LocalizedStringKey("accounts.add.card_limit"), text: $limitString).keyboardType(.decimalPad)
                    TextField("Güncel Borç (Opsiyonel)", text: $guncelBorcString).keyboardType(.decimalPad)
                }
                Section(header: Text("Hesap Kesim Tarihi")) {
                    DatePicker("Hesap Kesim Tarihi", selection: $kesimTarihi, displayedComponents: .date)
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
                    Button(LocalizedStringKey("common.save"), action: kaydet)
                        .disabled(isim.isEmpty || limitString.isEmpty)
                }
            }
            .onAppear(perform: formuDoldur)
        }
    }
    
    private func formuDoldur() {
        guard let hesap = duzenlenecekHesap, case .krediKarti(let limit, let tarih) = hesap.detay else { return }
        isim = hesap.isim
        limitString = String(limit)
        guncelBorcString = hesap.baslangicBakiyesi != 0 ? String(abs(hesap.baslangicBakiyesi)) : ""
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
            let yeniHesap = Hesap(
                isim: isim,
                ikonAdi: "creditcard.fill",
                renkHex: renkHex,
                baslangicBakiyesi: -guncelBorc,
                detay: kartDetayi
            )
            modelContext.insert(yeniHesap)
        }
        dismiss()
    }
}
