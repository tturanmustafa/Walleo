import SwiftUI

struct TarihAraligiSecimView: View {
    @Binding var secilenAralik: TarihAraligi
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Picker(LocalizedStringKey("filter.date_range"), selection: $secilenAralik) {
                    ForEach(TarihAraligi.allCases) { aralik in
                        // DEĞİŞİKLİK: Text'e artık doğrudan çeviri anahtarı veriliyor.
                        // 'aralik.localized' yerine 'aralik.rawValue' kullanıyoruz.
                        Text(LocalizedStringKey(aralik.rawValue)).tag(aralik)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
            .navigationTitle("filter.date_range")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.done") { dismiss() }.fontWeight(.bold)
                }
            }
        }
    }
}
