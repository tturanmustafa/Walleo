import SwiftUI
import SwiftData

struct BildirimlerView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appSettings: AppSettings
    
    @Query(sort: \Bildirim.olusturmaTarihi, order: .reverse) private var bildirimler: [Bildirim]

    var body: some View {
        NavigationStack {
            List {
                ForEach(bildirimler) { bildirim in
                    bildirimSatiri(for: bildirim)
                        .onTapGesture {
                            if !bildirim.okunduMu {
                                bildirim.okunduMu = true
                                // Değişikliğin hemen kaydedilmesi için bu satır önemli olabilir.
                                try? modelContext.save()
                            }
                        }
                }
                .onDelete(perform: deleteNotification)
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
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.delete") {
                        deleteAllNotifications()
                    }
                    .tint(.red)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("common.done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func deleteNotification(at offsets: IndexSet) {
        for index in offsets {
            let bildirim = bildirimler[index]
            modelContext.delete(bildirim)
        }
    }
    
    private func deleteAllNotifications() {
        try? modelContext.delete(model: Bildirim.self)
    }
    
    @ViewBuilder
    private func bildirimSatiri(for bildirim: Bildirim) -> some View {
        let (baslik, aciklama) = localizedDetails(for: bildirim)
        
        HStack(spacing: 15) {
            Image(systemName: ikon(for: bildirim.tur))
                .font(.title2)
                .foregroundColor(renk(for: bildirim.tur))
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(baslik)
                    .fontWeight(.semibold)
                Text(aciklama)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
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

    private func localizedDetails(for bildirim: Bildirim) -> (baslik: String, aciklama: String) {
        let dilKodu = appSettings.languageCode
        let paraKodu = appSettings.currencyCode
        
        guard let path = Bundle.main.path(forResource: dilKodu, ofType: "lproj"),
              let languageBundle = Bundle(path: path) else {
            return ("Notification Error", "Could not load language bundle.")
        }
        
        switch bildirim.tur {
        case .butceLimitiAsildi:
            let baslik = languageBundle.localizedString(forKey: "notification.budget.over_limit.title", value: "Budget Exceeded", table: nil)
            let formatString = languageBundle.localizedString(forKey: "notification.budget.over_limit.body_format", value: "You exceeded the %@ limit of your %@ budget by %@.", table: nil)
            
            let butceAdi = bildirim.ilgiliIsim ?? ""
            let limit = formatCurrency(amount: bildirim.tutar1 ?? 0, currencyCode: paraKodu, localeIdentifier: dilKodu)
            let asim = formatCurrency(amount: bildirim.tutar2 ?? 0, currencyCode: paraKodu, localeIdentifier: dilKodu)
            
            return (baslik, String(format: formatString, butceAdi, limit, asim))

        case .butceLimitiYaklasti:
            let baslik = languageBundle.localizedString(forKey: "notification.budget.approaching_limit.title", value: "Budget Limit Approaching", table: nil)
            let formatString = languageBundle.localizedString(forKey: "notification.budget.approaching_limit.body_format", value: "You have reached %@ of your %@ budget limit of %@.", table: nil)
            
            let butceAdi = bildirim.ilgiliIsim ?? ""
            let limit = formatCurrency(amount: bildirim.tutar1 ?? 0, currencyCode: paraKodu, localeIdentifier: dilKodu)
            let yuzde = String(format: "%%%.0f", (bildirim.tutar2 ?? 0) * 100)

            return (baslik, String(format: formatString, butceAdi, limit, yuzde))
            
        case .krediKartiOdemeGunu:
            let baslik = languageBundle.localizedString(forKey: "notification.credit_card.due_date.title", value: "Credit Card Payment Due", table: nil)
            let formatString = languageBundle.localizedString(forKey: "notification.credit_card.due_date.body_format", value: "The payment for your %@ card is due on %@.", table: nil)
            
            let kartAdi = bildirim.ilgiliIsim ?? ""
            
            // --- DÜZELTME BURADA ---
            // Karmaşık zincirleme yerine, daha basit ve standart bir format stili oluşturuyoruz.
            let formatStyle = Date.FormatStyle(date: .long, time: .omitted, locale: Locale(identifier: dilKodu))
            let odemeGunu = bildirim.tarih1?.formatted(formatStyle) ?? ""
            // --- DÜZELTME SONU ---

            return (baslik, String(format: formatString, kartAdi, odemeGunu))

        default:
            return ("Bilinmeyen Bildirim", "Detay yok.")
        }
    }

    private func ikon(for tur: BildirimTuru) -> String {
        switch tur {
        case .butceLimitiYaklasti: "exclamationmark.triangle.fill"
        case .butceLimitiAsildi: "exclamationmark.circle.fill"
        case .taksitHatirlatici: "calendar.badge.exclamationmark"
        case .krediKartiOdemeGunu: "creditcard.circle.fill"
        }
    }
    
    private func renk(for tur: BildirimTuru) -> Color {
        switch tur {
        case .butceLimitiYaklasti: .orange
        case .butceLimitiAsildi: .red
        case .taksitHatirlatici: .blue
        case .krediKartiOdemeGunu: .purple
        }
    }
}
