// Dosya Adı: BildirimlerView.swift (NİHAİ - LOKALİZE EDİLMİŞ)

import SwiftUI

struct BildirimlerView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                LocalizedStringKey("notifications.no_notifications_title"),
                systemImage: "bell.slash",
                description: Text(LocalizedStringKey("notifications.no_notifications_desc"))
            )
            .navigationTitle(LocalizedStringKey("notifications.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(LocalizedStringKey("common.done")) {
                        dismiss()
                    }
                }
            }
        }
    }
}
