// Dosya Adı: ButcelerView.swift

import SwiftUI

struct ButcelerView: View {
    var body: some View {
        NavigationStack {
            Text("Bütçeler Ekranı")
                // DÜZELTME: Sabit metin yerine LocalizedStringKey kullanılıyor.
                .navigationTitle(LocalizedStringKey("tab.budgets"))
        }
    }
}
