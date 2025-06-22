import SwiftUI
import SwiftData

struct BildirimlerView: View {
    @Environment(\.dismiss) var dismiss
    @Query(sort: \Bildirim.olusturmaTarihi, order: .reverse) private var bildirimler: [Bildirim]

    var body: some View {
        NavigationStack {
            List(bildirimler) { bildirim in
                bildirimSatiri(for: bildirim)
                    .onTapGesture {
                        if !bildirim.okunduMu {
                            bildirim.okunduMu = true
                        }
                    }
            }
            .overlay {
                if bildirimler.isEmpty {
                    ContentUnavailableView(
                        "notifications.no_notifications_title",
                        systemImage: "bell.slash",
                        description: Text("notifications.no_notifications_desc")
                    )
                }
            }
            .navigationTitle("notifications.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("common.done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func bildirimSatiri(for bildirim: Bildirim) -> some View {
        HStack(spacing: 15) {
            Image(systemName: ikon(for: bildirim.tur))
                .font(.title2)
                .foregroundColor(renk(for: bildirim.tur))
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(bildirim.baslik)
                    .fontWeight(.semibold)
                Text(bildirim.aciklama)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if !bildirim.okunduMu {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.vertical, 6)
    }

    private func ikon(for tur: BildirimTuru) -> String {
        switch tur {
        case .butceLimitiYaklasti: "exclamationmark.triangle.fill"
        case .butceLimitiAsildi: "exclamationmark.circle.fill"
        case .taksitHatirlatici: "calendar.badge.exclamationmark"
        // --- YENİ EKLENEN CASE ---
        case .krediKartiOdemeGunu: "creditcard.circle.fill"
        }
    }
    
    private func renk(for tur: BildirimTuru) -> Color {
        switch tur {
        case .butceLimitiYaklasti: .orange
        case .butceLimitiAsildi: .red
        case .taksitHatirlatici: .blue
        // --- YENİ EKLENEN CASE ---
        case .krediKartiOdemeGunu: .purple
        }
    }
}
