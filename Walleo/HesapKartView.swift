import SwiftUI

struct HesapKartView: View {
    let gosterilecekHesap: GosterilecekHesap
    @EnvironmentObject var appSettings: AppSettings
    var onEdit: () -> Void = {}
    var onDelete: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: gosterilecekHesap.hesap.ikonAdi).font(.headline).foregroundColor(.white).frame(width: 38, height: 38).background(gosterilecekHesap.hesap.renk).cornerRadius(8)
                Text(gosterilecekHesap.hesap.isim).font(.headline)
                Spacer()
                Menu {
                    Button(action: onEdit) { Label(LocalizedStringKey("common.edit"), systemImage: "pencil") }
                    Button(role: .destructive, action: onDelete) { Label(LocalizedStringKey("common.delete"), systemImage: "trash") }
                } label: {
                    Image(systemName: "ellipsis").font(.callout).foregroundColor(.secondary).frame(width: 40, height: 40).contentShape(Rectangle())
                }
            }
            
            // YENİ: Karmaşık switch ifadesini ayrı bir bileşene taşıdık
            // ve burada sadece o bileşeni çağırıyoruz. Bu, derleyiciyi rahatlatır.
            hesapDetayView
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // --- YENİ EKLENEN BÖLÜM ---
    // Switch ifadesini, kendi başına bir View döndüren bu bileşene taşıyoruz.
    @ViewBuilder
    private var hesapDetayView: some View {
        switch gosterilecekHesap.hesap.detay {
        case .cuzdan:
            cuzdanView()
            
        case .krediKarti(let limit, _, _): // Ofset'i de alıyoruz ama kullanmıyoruz
            krediKartiView(limit: limit)
        
        case .kredi(_, _, _, let taksitSayisi, _, _):
            krediView(toplamTaksit: taksitSayisi)
        }
    }
    // --- YENİ BÖLÜM SONU ---
    
    // Geri kalan yardımcı View'lar (cuzdanView, krediKartiView, krediView) aynı kalıyor.
    @ViewBuilder private func cuzdanView() -> some View {
        HStack {
            Text(LocalizedStringKey("accounts.add.wallet")).font(.subheadline).foregroundStyle(.secondary)
            Spacer()
            Text(formatCurrency(amount: gosterilecekHesap.guncelBakiye, currencyCode: appSettings.currencyCode, localeIdentifier: appSettings.languageCode)).font(.title2.bold()).foregroundColor(gosterilecekHesap.guncelBakiye < 0 ? .red : .primary)
        }
    }
    
    @ViewBuilder private func krediKartiView(limit: Double) -> some View {
        if let detay = gosterilecekHesap.krediKartiDetay {
            VStack(spacing: 12) {
                let isOverLimit = detay.guncelBorc > limit && limit > 0
                let progressValue = min(detay.guncelBorc, limit)
                
                ProgressView(value: progressValue, total: limit > 0 ? limit : 1)
                    .tint(isOverLimit ? .purple : .red)
                HStack {
                    VStack(alignment: .leading) {
                        Text(LocalizedStringKey("accounts.card.current_debt")).font(.caption).foregroundColor(.secondary)
                        Text(formatCurrency(amount: detay.guncelBorc, currencyCode: appSettings.currencyCode, localeIdentifier: appSettings.languageCode)).font(.callout.bold()).foregroundStyle(.red)
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text(LocalizedStringKey("accounts.card.available_limit")).font(.caption).foregroundColor(.secondary)
                        Text(formatCurrency(amount: detay.kullanilabilirLimit, currencyCode: appSettings.currencyCode, localeIdentifier: appSettings.languageCode)).font(.callout.bold()).foregroundStyle(.green)
                    }
                }
            }
        }
    }
    
    @ViewBuilder private func krediView(toplamTaksit: Int) -> some View {
        if let detay = gosterilecekHesap.krediDetay {
            VStack(spacing: 12) {
                ProgressView(value: Double(detay.odenenTaksitSayisi), total: Double(toplamTaksit) > 0 ? Double(toplamTaksit) : 1).tint(gosterilecekHesap.hesap.renk)
                HStack {
                    VStack(alignment: .leading) {
                        Text(LocalizedStringKey("accounts.card.paid_installments")).font(.caption).foregroundColor(.secondary)
                        Text("\(detay.odenenTaksitSayisi) / \(toplamTaksit)").font(.callout.bold())
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text(LocalizedStringKey("accounts.card.remaining_debt")).font(.caption).foregroundColor(.secondary)
                        Text(formatCurrency(amount: abs(gosterilecekHesap.guncelBakiye), currencyCode: appSettings.currencyCode, localeIdentifier: appSettings.languageCode))
                            .font(.callout.bold()).foregroundStyle(.red)
                    }
                }
            }
        }
    }
}
