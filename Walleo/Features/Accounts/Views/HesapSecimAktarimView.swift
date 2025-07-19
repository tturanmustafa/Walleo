//
//  HesapSecimAktarimView.swift
//  Walleo
//
//  Created by Mustafa Turan on 19.07.2025.
//


// YENİ DOSYA: Walleo/Features/Accounts/Views/HesapSecimAktarimView.swift

import SwiftUI
import SwiftData

struct HesapSecimAktarimView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appSettings: AppSettings
    
    // Bu view'a dışarıdan verilecek bilgiler
    let silinecekHesap: Hesap
    let uygunHesaplar: [Hesap]
    let onConfirm: (Hesap) -> Void // Kullanıcı onayladığında çalışacak fonksiyon
    
    // Bu view'ın kendi iç durumu
    @State private var secilenHedefHesapID: UUID?
    
    private var secilenHesap: Hesap? {
        uygunHesaplar.first { $0.id == secilenHedefHesapID }
    }
    
    // Metinleri doğru dilde ve formatta oluşturmak için
    private var aciklamaMetni: String {
        // 1. AppSettings'ten doğru dil paketini al
        let languageBundle = Bundle.getLanguageBundle(for: appSettings.languageCode)
        
        // 2. Formatlanacak ana metni bu paketten çek
        let formatString = languageBundle.localizedString(forKey: "transfer_transactions.message_format", value: "", table: nil)
        
        // 3. Metni verilerle formatla
        let islemSayisi = silinecekHesap.islemler?.count ?? 0
        return String(format: formatString, silinecekHesap.isim, islemSayisi)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                // Açıklama metni
                Text(aciklamaMetni)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                
                // Seçilebilir hesap listesi
                List {
                    ForEach(uygunHesaplar) { hesap in
                        Button(action: {
                            secilenHedefHesapID = hesap.id
                        }) {
                            HStack {
                                Image(systemName: secilenHedefHesapID == hesap.id ? "checkmark.circle.fill" : "circle")
                                    .font(.title2)
                                    .foregroundColor(secilenHedefHesapID == hesap.id ? .accentColor : .secondary)
                                
                                Image(systemName: hesap.ikonAdi)
                                    .frame(width: 30, height: 30)
                                    .background(hesap.renk.opacity(0.2))
                                    .foregroundColor(hesap.renk)
                                    .cornerRadius(6)
                                
                                Text(hesap.isim)
                                
                                Spacer()
                            }
                        }
                        .foregroundColor(.primary)
                    }
                }
                .listStyle(.insetGrouped)
            }
            .padding(.top)
            .navigationTitle(LocalizedStringKey("transfer_transactions.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("transfer_transactions.confirm_button")) {
                        if let secilenHesap = secilenHesap {
                            onConfirm(secilenHesap)
                            dismiss()
                        }
                    }
                    .disabled(secilenHedefHesapID == nil)
                    .fontWeight(.bold)
                }
            }
        }
    }
}
