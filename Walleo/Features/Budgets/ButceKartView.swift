import SwiftUI

struct ButceKartView: View {
    let gosterilecekButce: GosterilecekButce
    let isDuzenlenebilir: Bool // YENİ: Kartın düzenlenip düzenlenemeyeceğini dışarıdan alır.
    @EnvironmentObject var appSettings: AppSettings
    
    // Düzenleme ve Silme eylemleri için closure'lar
    var onEdit: () -> Void
    var onDelete: () -> Void

    // Hesaplanan değişkenler (Aynı kalıyor)
    private var limit: Double { gosterilecekButce.butce.limitTutar }
    private var harcanan: Double { gosterilecekButce.harcananTutar }
    private var kalan: Double { limit - harcanan }
    private var yuzde: Double {
        guard limit > 0, harcanan >= 0 else { return 0.0 }
        return min(1.0, harcanan / limit)
    }

    private var progressBarColor: Color {
        let gercekYuzde = limit > 0 ? harcanan / limit : 0
        if gercekYuzde >= 1.0 { return .red }
        if gercekYuzde > 0.8 { return .orange }
        return .green
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(gosterilecekButce.butce.isim)
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
                Menu {
                    // --- DÜZELTME: Düzenle butonu artık koşullu ---
                    if isDuzenlenebilir {
                        Button(action: onEdit) {
                            Label("common.edit", systemImage: "pencil")
                        }
                    }
                    Button(role: .destructive, action: onDelete) {
                        Label("common.delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle.fill")
                        .font(.callout)
                        .foregroundColor(.secondary.opacity(0.7))
                        .frame(width: 30, height: 30, alignment: .trailing)
                }
            }
            
            ProgressView(value: yuzde)
                .tint(progressBarColor)
                .scaleEffect(x: 1, y: 2.0, anchor: .center)
                .padding(.bottom, 4)

            VStack(spacing: 8) {
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
            
            if let kategoriler = gosterilecekButce.butce.kategoriler, !kategoriler.isEmpty {
                Divider().padding(.top, 4)
                
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
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
    }
}
