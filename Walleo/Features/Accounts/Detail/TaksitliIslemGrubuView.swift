// GÜNCELLENMİŞ DOSYA: TaksitliIslemGrubuView.swift

import SwiftUI

struct TaksitliIslemGrubuView: View {
    @EnvironmentObject var appSettings: AppSettings
    
    let grup: KrediKartiDetayViewModel.TaksitliIslemGrubu
    let isExpanded: Bool
    let onToggle: () -> Void
    let onEdit: (Islem) -> Void
    let onDelete: (Islem) -> Void
    
    // YENİ: Açıklama metnini cache'le
    private var aciklamaMetni: String {
        grup.aciklamaMetni(using: appSettings)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Ana satır (Başlık)
            Button(action: onToggle) {
                HStack {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption).foregroundColor(.secondary).frame(width: 20)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(grup.anaIsim)
                            .fontWeight(.semibold)
                        // YENİ: Cached değeri kullan
                        Text(aciklamaMetni)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "creditcard.viewfinder")
                        .font(.callout).foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            
            // Taksit detayları (Genişletildiğinde)
            if isExpanded {
                LazyVStack(spacing: 0) { // YENİ: LazyVStack kullan
                    ForEach(grup.taksitler) { taksit in
                        taksitSatiri(taksit)
                        
                        if taksit.id != grup.taksitler.last?.id {
                            Divider().padding(.leading, 40)
                        }
                    }
                }
                .padding(.leading, 20)
            }
        }
    }
    
    @ViewBuilder
    private func taksitSatiri(_ taksit: Islem) -> some View {
        let gecmisTarihMi = taksit.tarih <= Date()
        
        // YENİ: Formatlanmış değerleri cache'le
        let languageBundle = Bundle.getLanguageBundle(for: appSettings.languageCode)
        let formatString = languageBundle.localizedString(forKey: "credit_card.installment_number_format", value: "", table: nil)
        let taksitBasligi = String(format: formatString, taksit.mevcutTaksitNo)
        let tarihMetni = formatDateForList(from: taksit.tarih, localeIdentifier: appSettings.languageCode)
        let tutarMetni = formatCurrency(amount: taksit.tutar, currencyCode: appSettings.currencyCode, localeIdentifier: appSettings.languageCode)

        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(taksitBasligi)
                    .font(.subheadline).fontWeight(.medium)
                    .strikethrough(gecmisTarihMi)
                    .foregroundColor(gecmisTarihMi ? .secondary : .primary)
                
                Text(tarihMetni)
                    .font(.caption).foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(tutarMetni)
                .font(.callout.bold())
                .strikethrough(gecmisTarihMi)
                .foregroundColor(gecmisTarihMi ? .secondary : .primary)
                .monospacedDigit() // YENİ: Sayıların hizalanması için
            
            Menu {
                Button(LocalizedStringKey("common.edit"), systemImage: "pencil") { onEdit(taksit) }
                Button(LocalizedStringKey("common.delete"), systemImage: "trash", role: .destructive) { onDelete(taksit) }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.caption).foregroundColor(.secondary)
                    .frame(width: 30, height: 30).contentShape(Rectangle())
            }
            // YENİ: Menu optimizasyonu
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
        }
        .padding(.vertical, 6)
        .opacity(gecmisTarihMi ? 0.7 : 1.0)
    }
}
