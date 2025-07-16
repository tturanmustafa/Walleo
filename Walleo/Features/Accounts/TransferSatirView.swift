// Walleo/Components/TransferSatirView.swift

import SwiftUI

struct TransferSatirView: View {
    @EnvironmentObject var appSettings: AppSettings
    let transfer: Transfer
    let hesapID: UUID
    
    // Bu transfer gelen mi giden mi?
    private var isGelen: Bool {
        transfer.hedefHesap?.id == hesapID
    }
    
    private var karsiHesapAdi: String {
        if isGelen {
            return transfer.kaynakHesap?.isim ?? NSLocalizedString("transfer.unknown_account", comment: "")
        } else {
            return transfer.hedefHesap?.isim ?? NSLocalizedString("transfer.unknown_account", comment: "")
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // İkon
            ZStack {
                Circle()
                    .fill(isGelen ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                    .frame(width: 45, height: 45)
                
                Image(systemName: isGelen ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                    .font(.headline)
                    .foregroundColor(isGelen ? .green : .red)
            }
            
            // Detaylar
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(LocalizedStringKey(isGelen ? "transfer.incoming" : "transfer.outgoing"))
                        .fontWeight(.semibold)
                    Text("•")
                        .foregroundColor(.secondary)
                    Text(karsiHesapAdi)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Text(formatDateForList(from: transfer.tarih, localeIdentifier: appSettings.languageCode))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Tutar
            Text(formatCurrency(
                amount: transfer.tutar,
                currencyCode: appSettings.currencyCode,
                localeIdentifier: appSettings.languageCode
            ))
            .font(.callout.bold())
            .foregroundColor(isGelen ? .green : .red)
        }
        .padding(.vertical, 4)
    }
}
