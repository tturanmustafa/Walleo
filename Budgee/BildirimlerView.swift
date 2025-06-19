import SwiftUI

struct BildirimlerView: View {
    // Bu View'ı kapatmak için Environment'tan dismiss eylemini alıyoruz.
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            // Şimdilik boş bir içerik.
            ContentUnavailableView(
                "Henüz bildirim yok",
                systemImage: "bell.slash",
                description: Text("Uygulama içi önemli bildirimleriniz burada görünecektir.")
            )
            .navigationTitle(LocalizedStringKey("notifications.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Bitti") { // Bu metin de localize edilebilir ("common.done")
                        dismiss()
                    }
                }
            }
        }
    }
}
