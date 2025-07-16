//
//  TaksitliIslemGrubuView.swift
//  Walleo
//
//  Created by Mustafa Turan on 16.07.2025.
//


// YENİ DOSYA: TaksitliIslemGrubuView.swift

import SwiftUI

struct TaksitliIslemGrubuView: View {
    @EnvironmentObject var appSettings: AppSettings
    
    let grup: KrediKartiDetayViewModel.TaksitliIslemGrubu
    let isExpanded: Bool
    let onToggle: () -> Void
    let onEdit: (Islem) -> Void
    let onDelete: (Islem) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Ana satır (Başlık)
            Button(action: onToggle) {
                HStack {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 20)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(grup.anaIsim)
                            .fontWeight(.semibold)
                        Text(grup.aciklamaMetni)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "creditcard.viewfinder")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            
            // Taksit detayları (Genişletildiğinde)
            if isExpanded {
                VStack(spacing: 0) {
                    ForEach(grup.taksitler) { taksit in
                        taksitSatiri(taksit)
                        
                        if taksit.id != grup.taksitler.last?.id {
                            Divider()
                                .padding(.leading, 40)
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
        
        HStack {
            // Taksit numarası ve tutar
            VStack(alignment: .leading, spacing: 2) {
                Text("\(taksit.mevcutTaksitNo). Taksit")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .strikethrough(gecmisTarihMi)
                    .foregroundColor(gecmisTarihMi ? .secondary : .primary)
                
                Text(formatDateForList(from: taksit.tarih, localeIdentifier: appSettings.languageCode))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(formatCurrency(
                amount: taksit.tutar,
                currencyCode: appSettings.currencyCode,
                localeIdentifier: appSettings.languageCode
            ))
            .font(.callout.bold())
            .strikethrough(gecmisTarihMi)
            .foregroundColor(gecmisTarihMi ? .secondary : .primary)
            
            // Menu
            Menu {
                Button(LocalizedStringKey("common.edit"), systemImage: "pencil") { 
                    onEdit(taksit) 
                }
                Button(LocalizedStringKey("common.delete"), systemImage: "trash", role: .destructive) { 
                    onDelete(taksit) 
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 30, height: 30)
                    .contentShape(Rectangle())
            }
        }
        .padding(.vertical, 6)
        .opacity(gecmisTarihMi ? 0.7 : 1.0)
    }
}