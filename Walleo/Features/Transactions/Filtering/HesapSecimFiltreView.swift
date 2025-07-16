//
//  HesapSecimFiltreView.swift
//  Walleo
//
//  Created by Mustafa Turan on 17.07.2025.
//


import SwiftUI
import SwiftData

struct HesapSecimFiltreView: View {
    @Binding var secilenHesaplar: Set<UUID>
    @Query(sort: \Hesap.olusturmaTarihi) private var tumHesaplar: [Hesap]
    @Environment(\.dismiss) private var dismiss
    
    // Hesapları Cüzdan ve Kredi Kartı olarak ayırıyoruz
    private var cuzdanHesaplari: [Hesap] {
        tumHesaplar.filter {
            if case .cuzdan = $0.detay { return true }
            return false
        }
    }
    
    private var krediKartiHesaplari: [Hesap] {
        tumHesaplar.filter {
            if case .krediKarti = $0.detay { return true }
            return false
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                // Cüzdanlar Bölümü
                Section(header: Text("accounts.group.wallets")) {
                    ForEach(cuzdanHesaplari) { hesap in
                        hesapSatiri(hesap)
                    }
                }
                
                // Kredi Kartları Bölümü
                Section(header: Text("accounts.group.credit_cards")) {
                    ForEach(krediKartiHesaplari) { hesap in
                        hesapSatiri(hesap)
                    }
                }
            }
            .navigationTitle("filter.accounts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.reset") { secilenHesaplar.removeAll() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.done") { dismiss() }.fontWeight(.bold)
                }
            }
        }
    }
    
    // Her bir hesap satırını oluşturan yardımcı view
    @ViewBuilder
    private func hesapSatiri(_ hesap: Hesap) -> some View {
        Button(action: {
            toggleHesap(hesap.id)
        }) {
            HStack {
                Image(systemName: secilenHesaplar.contains(hesap.id) ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(secilenHesaplar.contains(hesap.id) ? .blue : .secondary)
                
                Image(systemName: hesap.ikonAdi)
                    .frame(width: 24, height: 24)
                    .background(hesap.renk.opacity(0.2))
                    .foregroundColor(hesap.renk)
                    .cornerRadius(5)

                Text(hesap.isim)
                
                Spacer()
            }
        }
        .foregroundColor(.primary)
    }
    
    // Seçimi açıp/kapatan fonksiyon
    private func toggleHesap(_ id: UUID) {
        if secilenHesaplar.contains(id) {
            secilenHesaplar.remove(id)
        } else {
            secilenHesaplar.insert(id)
        }
    }
}