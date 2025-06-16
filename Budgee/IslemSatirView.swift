import SwiftUI

struct IslemSatirView: View {
    let islem: Islem
    
    var onEdit: () -> Void = {}
    var onDelete: () -> Void = {}

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                // Kategorinin kendi rengini %10 opaklıkta arka plan olarak kullan
                Circle()
                    .fill(islem.kategori?.renk.opacity(0.1) ?? Color.gray.opacity(0.1))
                    .frame(width: 45, height: 45)
                
                // Kategorinin kendi ikonunu ve rengini kullan
                Image(systemName: islem.kategori?.ikonAdi ?? "tag.fill")
                    .font(.callout)
                    .foregroundColor(islem.kategori?.renk ?? .gray)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(islem.isim).fontWeight(.semibold)
                Text(formatDateForList(from: islem.tarih)).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            
            formatCurrency(amount: islem.tutar, font: .callout, color: islem.tur == .gelir ? .green : .primary)
            
            Menu {
                Button("Düzenle", systemImage: "pencil", action: onEdit)
                Button("Sil", systemImage: "trash", role: .destructive, action: onDelete)
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
