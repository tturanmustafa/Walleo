import SwiftUI

struct IslemSatirView: View {
    @EnvironmentObject var appSettings: AppSettings
    let islem: Islem
    
    var onEdit: () -> Void = {}
    var onDelete: () -> Void = {}

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(islem.kategori?.renk.opacity(0.1) ?? Color.gray.opacity(0.1))
                    .frame(width: 45, height: 45)
                
                Image(systemName: islem.kategori?.ikonAdi ?? "tag.fill")
                    .font(.headline)
                    .foregroundColor(islem.kategori?.renk ?? .gray)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(islem.isim).fontWeight(.semibold)
                Text(formatDateForList(from: islem.tarih)).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            
            Text(formatCurrency(
                amount: islem.tutar,
                currencyCode: appSettings.currencyCode,
                localeIdentifier: appSettings.languageCode
            ))
            .font(.callout.bold()) // TEK BİR FONT KULLANILIYOR
            .foregroundColor(islem.tur == .gelir ? .green : .primary)
            
            Menu {
                Button(LocalizedStringKey("common.edit"), systemImage: "pencil", action: onEdit)
                Button(LocalizedStringKey("common.delete"), systemImage: "trash", role: .destructive, action: onDelete)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .frame(width: 30, height: 40)
                    .contentShape(Rectangle())
            }
        }
        .padding(.vertical, 4)
    }
}
