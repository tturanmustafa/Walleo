// IslemSatirView.swift

import SwiftUI

struct IslemSatirView: View {
    @EnvironmentObject var appSettings: AppSettings
    let islem: Islem
    
    var onEdit: () -> Void = {}
    var onDelete: () -> Void = {}
    
    // YENİ: Hesaplanmış değerleri cache'le
    private var kategoriRenk: Color {
        islem.kategori?.renk ?? .gray
    }
    
    private var kategoriIkon: String {
        islem.kategori?.ikonAdi ?? "tag.fill"
    }
    
    private var formatlanmisTarih: String {
        formatDateForList(from: islem.tarih, localeIdentifier: appSettings.languageCode)
    }
    
    private var formatlanmisTutar: String {
        formatCurrency(
            amount: islem.tutar,
            currencyCode: appSettings.currencyCode,
            localeIdentifier: appSettings.languageCode
        )
    }

    var body: some View {
        HStack(spacing: 12) {
            // YENİ: İkon bölümünü optimize et
            iconView
            
            // YENİ: Detay bölümünü optimize et
            detailView
            
            Spacer()
            
            // YENİ: Tutar bölümünü optimize et
            amountView
            
            // YENİ: Menu bölümünü optimize et
            menuView
        }
        .padding(.vertical, 4)
        // YENİ: Satırın tamamını tıklanabilir yap (performans için)
        .contentShape(Rectangle())
    }
    
    // YENİ: İkon view
    @ViewBuilder
    private var iconView: some View {
        ZStack {
            Circle()
                .fill(kategoriRenk.opacity(0.1))
                .frame(width: 45, height: 45)
            
            Image(systemName: kategoriIkon)
                .font(.headline)
                .foregroundColor(kategoriRenk)
        }
        // YENİ: Gereksiz animasyonları kaldır
        .drawingGroup()
    }
    
    // YENİ: Detay view
    @ViewBuilder
    private var detailView: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(islem.isim)
                .fontWeight(.semibold)
                .lineLimit(1)
                .truncationMode(.tail)
            
            Text(formatlanmisTarih)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // YENİ: Tutar view
    @ViewBuilder
    private var amountView: some View {
        Text(formatlanmisTutar)
            .font(.callout.bold())
            .foregroundColor(islem.tur == .gelir ? .green : .primary)
            // YENİ: Sayıların hizalanması için
            .monospacedDigit()
    }
    
    // YENİ: Menu view
    @ViewBuilder
    private var menuView: some View {
        Menu {
            Button(action: onEdit) {
                Label("common.edit", systemImage: "pencil")
            }
            
            Button(role: .destructive, action: onDelete) {
                Label("common.delete", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.callout)
                .foregroundColor(.secondary)
                .frame(width: 30, height: 40)
                .contentShape(Rectangle())
        }
        // YENİ: Menu açılmasını optimize et
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
    }
}

// YENİ: Preview için extension
#if DEBUG
extension IslemSatirView {
    static var preview: some View {
        IslemSatirView(
            islem: Islem(
                isim: "Örnek İşlem",
                tutar: 150.50,
                tarih: Date(),
                tur: .gider,
                kategori: nil,
                hesap: nil
            )
        )
        .environmentObject(AppSettings())
        .padding()
    }
}
#endif
