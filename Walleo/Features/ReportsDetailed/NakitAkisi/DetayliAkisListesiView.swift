//
//  DetayliAkisListesiView.swift
//  Walleo
//
//  Created by Mustafa Turan on 18.07.2025.
//


// Walleo/Features/ReportsDetailed/NakitAkisi/Views/DetayliAkisListesiView.swift

import SwiftUI

struct DetayliAkisListesiView: View {
    let gunlukVeriler: [GunlukNakitAkisi]
    @EnvironmentObject var appSettings: AppSettings
    @State private var genisletilmisGunler: Set<UUID> = []
    
    private var haftalikGruplar: [(hafta: String, gunler: [GunlukNakitAkisi], toplamNet: Double)] {
        let calendar = Calendar.current
        let gruplar = Dictionary(grouping: gunlukVeriler) { veri in
            calendar.dateInterval(of: .weekOfYear, for: veri.tarih)?.start ?? veri.tarih
        }
        
        return gruplar.map { (haftaBasi, gunler) in
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: appSettings.languageCode)
            formatter.dateFormat = "d MMM"
            
            let haftaSonu = calendar.date(byAdding: .day, value: 6, to: haftaBasi) ?? haftaBasi
            let haftaEtiketi = "\(formatter.string(from: haftaBasi)) - \(formatter.string(from: haftaSonu))"
            let toplamNet = gunler.reduce(0) { $0 + $1.netAkis }
            
            return (haftaEtiketi, gunler.sorted { $0.tarih < $1.tarih }, toplamNet)
        }.sorted { $0.gunler.first?.tarih ?? Date() < $1.gunler.first?.tarih ?? Date() }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("cashflow.daily_details")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            VStack(spacing: 12) {
                ForEach(haftalikGruplar, id: \.hafta) { grup in
                    haftaGrubuView(hafta: grup.hafta, gunler: grup.gunler, toplamNet: grup.toplamNet)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
    
    @ViewBuilder
    private func haftaGrubuView(hafta: String, gunler: [GunlukNakitAkisi], toplamNet: Double) -> some View {
        VStack(spacing: 0) {
            // Hafta başlığı
            HStack {
                Text(hafta)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text(formatCurrency(
                    amount: toplamNet,
                    currencyCode: appSettings.currencyCode,
                    localeIdentifier: appSettings.languageCode
                ))
                .font(.subheadline.bold())
                .foregroundColor(toplamNet >= 0 ? .green : .red)
            }
            .padding()
            .background(Color(.tertiarySystemGroupedBackground))
            
            // Günlük detaylar
            VStack(spacing: 0) {
                ForEach(gunler) { gun in
                    gunlukSatirView(gun: gun)
                    
                    if gun.id != gunler.last?.id {
                        Divider()
                            .padding(.leading, 16)
                    }
                }
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
    }
    
    @ViewBuilder
    private func gunlukSatirView(gun: GunlukNakitAkisi) -> some View {
        let isExpanded = genisletilmisGunler.contains(gun.id)
        
        VStack(spacing: 0) {
            Button(action: {
                withAnimation(.spring(response: 0.3)) {
                    if isExpanded {
                        genisletilmisGunler.remove(gun.id)
                    } else {
                        genisletilmisGunler.insert(gun.id)
                    }
                }
            }) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(gun.tarih, format: .dateTime.weekday(.abbreviated).day())
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        HStack(spacing: 12) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.up")
                                    .font(.caption2)
                                    .foregroundColor(.green)
                                Text(formatCurrency(
                                    amount: gun.gelir,
                                    currencyCode: appSettings.currencyCode,
                                    localeIdentifier: appSettings.languageCode
                                ))
                                .font(.caption)
                            }
                            
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.down")
                                    .font(.caption2)
                                    .foregroundColor(.red)
                                Text(formatCurrency(
                                    amount: gun.gider,
                                    currencyCode: appSettings.currencyCode,
                                    localeIdentifier: appSettings.languageCode
                                ))
                                .font(.caption)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(formatCurrency(
                            amount: gun.netAkis,
                            currencyCode: appSettings.currencyCode,
                            localeIdentifier: appSettings.languageCode
                        ))
                        .font(.subheadline.bold())
                        .foregroundColor(gun.netAkis >= 0 ? .green : .red)
                        
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            
            // Genişletilmiş detaylar
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    Divider()
                    
                    // İşlem tipi detayları
                    VStack(spacing: 8) {
                        if gun.normalGelir > 0 || gun.normalGider > 0 {
                            islemTipiSatiri(
                                baslikKey: "cashflow.normal_transactions", // DÜZELTİLDİ
                                gelir: gun.normalGelir,
                                gider: gun.normalGider,
                                ikon: "arrow.right.circle"
                            )
                        }
                        
                        if gun.taksitliGelir > 0 || gun.taksitliGider > 0 {
                            islemTipiSatiri(
                                baslikKey: "cashflow.installment_transactions", // DÜZELTİLDİ
                                gelir: gun.taksitliGelir,
                                gider: gun.taksitliGider,
                                ikon: "creditcard"
                            )
                        }
                        
                        if gun.tekrarliGelir > 0 || gun.tekrarliGider > 0 {
                            islemTipiSatiri(
                                baslikKey: "cashflow.recurring_transactions", // DÜZELTİLDİ
                                gelir: gun.tekrarliGelir,
                                gider: gun.tekrarliGider,
                                ikon: "arrow.clockwise"
                            )
                        }
                    }
                    
                    Divider()
                    
                    // Kümülatif bakiye
                    HStack {
                        Text("cashflow.cumulative_balance")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        Text(formatCurrency(
                            amount: gun.kumulatifBakiye,
                            currencyCode: appSettings.currencyCode,
                            localeIdentifier: appSettings.languageCode
                        ))
                        .font(.caption.bold())
                        .foregroundColor(gun.kumulatifBakiye >= 0 ? .primary : .red)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 12)
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))
            }
        }
    }
    
    @ViewBuilder
    private func islemTipiSatiri(baslikKey: String, gelir: Double, gider: Double, ikon: String) -> some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: ikon)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Text(LocalizedStringKey(baslikKey)) // DÜZELTİLDİ
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if gelir > 0 {
                Text("+\(formatCurrency(amount: gelir, currencyCode: appSettings.currencyCode, localeIdentifier: appSettings.languageCode))")
                    .font(.caption)
                    .foregroundColor(.green)
            }
            
            if gider > 0 {
                Text("-\(formatCurrency(amount: gider, currencyCode: appSettings.currencyCode, localeIdentifier: appSettings.languageCode))")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }
}
