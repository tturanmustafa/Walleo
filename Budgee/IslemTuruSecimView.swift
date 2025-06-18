import SwiftUI

struct IslemTuruSecimView: View {
    @Binding var secilenTurler: Set<IslemTuru>
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Spacer()
                // DEĞİŞİKLİK: Artık 'NSLocalizedString' kullanmıyoruz, doğrudan anahtarı veriyoruz.
                FiltrePillView(titleKey: "common.all", isSelected: secilenTurler.count != 1) {
                    secilenTurler = [.gelir, .gider]
                    dismiss()
                }
                FiltrePillView(titleKey: "common.income", isSelected: secilenTurler == [.gelir]) {
                    secilenTurler = [.gelir]
                    dismiss()
                }
                FiltrePillView(titleKey: "common.expense", isSelected: secilenTurler == [.gider]) {
                    secilenTurler = [.gider]
                    dismiss()
                }
                Spacer()
            }
            .padding()
            .navigationTitle("transaction.type")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
