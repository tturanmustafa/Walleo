import SwiftUI

struct ButceKartView: View {
    let gosterilecekButce: GosterilecekButce
    @EnvironmentObject var appSettings: AppSettings
    
    var onEdit: () -> Void = {}
    var onDelete: () -> Void = {}

    // --- Hesaplanmış Değişkenler (Aynı kalıyor) ---
    private var limit: Double { gosterilecekButce.butce.limitTutar }
    private var harcanan: Double { gosterilecekButce.harcananTutar }
    private var kalan: Double { limit - harcanan }
    private var yuzde: Double { limit > 0 ? (harcanan / limit) : 0 }

    private var progressBarColor: Color {
        if yuzde >= 1.0 { return .red }
        if yuzde > 0.8 { return .orange }
        return .green
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Sağ üst menü ve başlık (Aynı kalıyor)
            HStack {
                Text(gosterilecekButce.butce.isim)
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
                Menu {
                    Button(action: onEdit) {
                        Label(LocalizedStringKey("common.edit"), systemImage: "pencil")
                    }
                    Button(role: .destructive, action: onDelete) {
                        Label(LocalizedStringKey("common.delete"), systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle.fill")
                        .font(.callout)
                        .foregroundColor(.secondary.opacity(0.7))
                        .frame(width: 30, height: 30, alignment: .trailing)
                }
            }
            
            // Progress bar (Aynı kalıyor)
            ProgressView(value: harcanan, total: limit > 0 ? limit : 1)
                .tint(progressBarColor)
                .scaleEffect(x: 1, y: 2.0, anchor: .center)
                .padding(.bottom, 4)

            // Tutar bilgileri (Aynı kalıyor)
            VStack(spacing: 8) {
                // ... Toplam, Harcanan, Kalan satırları ...
                HStack {
                    Text(LocalizedStringKey("budgets.card.total_limit"))
                        .font(.callout)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(formatCurrency(amount: limit, currencyCode: appSettings.currencyCode, localeIdentifier: appSettings.languageCode))
                        .font(.callout)
                        .fontWeight(.bold)
                }
                
                Divider()

                HStack {
                    Text(LocalizedStringKey("budgets.card.amount_spent"))
                        .font(.callout)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(formatCurrency(amount: harcanan, currencyCode: appSettings.currencyCode, localeIdentifier: appSettings.languageCode))
                        .font(.callout).fontWeight(.semibold)
                        .foregroundColor(progressBarColor)
                }
                
                Divider()
                
                HStack {
                    Text(LocalizedStringKey("budgets.card.amount_remaining"))
                        .font(.callout)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(formatCurrency(amount: kalan, currencyCode: appSettings.currencyCode, localeIdentifier: appSettings.languageCode))
                        .font(.callout)
                        .foregroundColor(kalan < 0 ? .red : .primary)
                }
            }
            
            // --- YENİ EKLENEN BÖLÜM ---
            // Kategorilerin ikonlarını gösteren bölüm
            if let kategoriler = gosterilecekButce.butce.kategoriler, !kategoriler.isEmpty {
                            Divider().padding(.top, 4)
                            
                            // WrappingHStack ile etiketlerin alt satıra kaymasını sağlıyoruz.
                            WrappingHStack(items: kategoriler) { kategori in
                                HStack(spacing: 4) {
                                    Image(systemName: kategori.ikonAdi)
                                        .font(.caption)
                                    Text(LocalizedStringKey(kategori.localizationKey ?? kategori.isim))
                                        .font(.caption)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(kategori.renk.opacity(0.2))
                                .foregroundColor(kategori.renk)
                                .cornerRadius(12)
                            }
                            .padding(.top, 4)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
}
