//
//  KrediKartiTahminView.swift
//  Walleo
//
//  Created by Mustafa Turan on 15.07.2025.
//


// >> YENİ DOSYA: Features/ReportsDetailed/Views/KrediKartiTahminView.swift

import SwiftUI

struct KrediKartiTahminView: View {
    let tahminler: [UUID: LimitTahmini]
    let genelTahmin: LimitTahmini?
    @EnvironmentObject var appSettings: AppSettings
    
    @State private var secilenKartID: UUID?
    @State private var animasyonTamamlandi = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Genel tahmin
                if let tahmin = genelTahmin {
                    GenelTahminKarti(
                        tahmin: tahmin,
                        animasyonTamamlandi: animasyonTamamlandi
                    )
                    .padding(.horizontal)
                }
                
                // Kart bazlı tahminler
                if !tahminler.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(LocalizedStringKey("reports.credit_card.card_predictions"))
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ForEach(Array(tahminler.keys), id: \.self) { kartID in
                            if let tahmin = tahminler[kartID] {
                                KartTahminKarti(
                                    kartID: kartID,
                                    tahmin: tahmin,
                                    isExpanded: secilenKartID == kartID,
                                    animasyonTamamlandi: animasyonTamamlandi
                                )
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.3)) {
                                        secilenKartID = secilenKartID == kartID ? nil : kartID
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                }
                
                // Öneriler
                OneriPaneli(
                    riskSeviyesi: genelTahmin?.riskSeviyesi ?? .dusuk
                )
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                animasyonTamamlandi = true
            }
        }
    }
}

// Genel tahmin kartı
struct GenelTahminKarti: View {
    let tahmin: LimitTahmini
    let animasyonTamamlandi: Bool
    @EnvironmentObject var appSettings: AppSettings
    
    @State private var displayedPercentage: Double = 0
    
    var body: some View {
        VStack(spacing: 20) {
            // Başlık ve risk göstergesi
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(LocalizedStringKey("reports.credit_card.month_end_prediction"))
                        .font(.headline)
                    
                    Label(LocalizedStringKey(tahmin.riskSeviyesi.mesajKey), systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(tahmin.riskSeviyesi.renk)
                }
                
                Spacer()
                
                // Risk seviyesi göstergesi
                RiskSeviyesiGostergesi(
                    seviye: tahmin.riskSeviyesi,
                    animasyonTamamlandi: animasyonTamamlandi
                )
            }
            
            // Tahmin göstergesi
            VStack(spacing: 16) {
                // Mevcut vs Tahmin karşılaştırması
                HStack(spacing: 0) {
                    // Mevcut kullanım
                    VStack(spacing: 4) {
                        Text(LocalizedStringKey("reports.credit_card.current"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("\(Int(tahmin.mevcutKullanimOrani * 100))%")
                            .font(.title2.bold())
                            .foregroundColor(.blue)
                    }
                    .frame(maxWidth: .infinity)
                    
                    // Animasyonlu ok
                    Image(systemName: "arrow.right")
                        .font(.title2)
                        .foregroundColor(.secondary)
                        .offset(x: animasyonTamamlandi ? 0 : -20)
                        .opacity(animasyonTamamlandi ? 1 : 0)
                    
                    // Tahmin edilen
                    VStack(spacing: 4) {
                        Text(LocalizedStringKey("reports.credit_card.predicted"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("\(Int(displayedPercentage))%")
                            .font(.title2.bold())
                            .foregroundColor(tahmin.riskSeviyesi.renk)
                            .contentTransition(.numericText())
                    }
                    .frame(maxWidth: .infinity)
                }
                
                // İlerleme çubuğu
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Arka plan
                        Capsule()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 20)
                        
                        // Mevcut kullanım
                        Capsule()
                            .fill(Color.blue)
                            .frame(width: geometry.size.width * tahmin.mevcutKullanimOrani, height: 20)
                        
                        // Tahmin edilen (üst üste binme efekti)
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color.blue.opacity(0.5), tahmin.riskSeviyesi.renk.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(
                                width: animasyonTamamlandi ? geometry.size.width * min(tahmin.tahminEdileAysonuKullanim, 1.0) : geometry.size.width * tahmin.mevcutKullanimOrani,
                                height: 20
                            )
                            .animation(.spring(response: 1.0, dampingFraction: 0.8), value: animasyonTamamlandi)
                        
                        // %100 çizgisi
                        if tahmin.tahminEdileAysonuKullanim > 1.0 {
                            Rectangle()
                                .fill(Color.red)
                                .frame(width: 2, height: 30)
                                .position(x: geometry.size.width, y: 15)
                        }
                    }
                }
                .frame(height: 20)
                
                // Önerilen günlük limit
                if tahmin.onerilenGunlukLimit > 0 {
                    HStack {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(.yellow)
                        
                        Text(LocalizedStringKey("reports.credit_card.suggested_daily_limit"))
                            .font(.subheadline)
                        
                        Spacer()
                        
                        Text(formatCurrency(
                            amount: tahmin.onerilenGunlukLimit,
                            currencyCode: appSettings.currencyCode,
                            localeIdentifier: appSettings.languageCode
                        ))
                        .font(.headline.bold())
                        .foregroundColor(.green)
                    }
                    .padding()
                    .background(Color(.tertiarySystemGroupedBackground))
                    .cornerRadius(12)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .onAppear {
            withAnimation(.easeOut(duration: 1.2)) {
                displayedPercentage = tahmin.tahminEdileAysonuKullanim * 100
            }
        }
    }
}

// Risk seviyesi göstergesi
struct RiskSeviyesiGostergesi: View {
    let seviye: RiskSeviyesi
    let animasyonTamamlandi: Bool
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(1...3, id: \.self) { level in
                Capsule()
                    .fill(level <= seviye.rawValue ? seviye.renk : Color.gray.opacity(0.3))
                    .frame(width: 30, height: 8)
                    .scaleEffect(animasyonTamamlandi && level <= seviye.rawValue ? 1.0 : 0.8)
                    .animation(
                        .spring(response: 0.5, dampingFraction: 0.6)
                        .delay(Double(level) * 0.1),
                        value: animasyonTamamlandi
                    )
            }
        }
    }
}

// Öneri paneli
struct OneriPaneli: View {
    let riskSeviyesi: RiskSeviyesi
    @State private var genisletildi = false
    
    private var oneriler: [Oneri] {
        switch riskSeviyesi {
        case .dusuk:
            return [
                Oneri(ikon: "checkmark.circle.fill", mesajKey: "suggestion.low_risk.1", renk: .green),
                Oneri(ikon: "star.fill", mesajKey: "suggestion.low_risk.2", renk: .yellow)
            ]
        case .orta:
            return [
                Oneri(ikon: "exclamationmark.triangle.fill", mesajKey: "suggestion.medium_risk.1", renk: .orange),
                Oneri(ikon: "chart.line.downtrend.xyaxis", mesajKey: "suggestion.medium_risk.2", renk: .blue)
            ]
        case .yuksek:
            return [
                Oneri(ikon: "exclamationmark.circle.fill", mesajKey: "suggestion.high_risk.1", renk: .red),
                Oneri(ikon: "scissors", mesajKey: "suggestion.high_risk.2", renk: .purple),
                Oneri(ikon: "calendar.badge.exclamationmark", mesajKey: "suggestion.high_risk.3", renk: .orange)
            ]
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: {
                withAnimation(.spring(response: 0.3)) {
                    genisletildi.toggle()
                }
            }) {
                HStack {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.yellow)
                    
                    Text(LocalizedStringKey("reports.credit_card.suggestions"))
                        .font(.headline)
                    
                    Spacer()
                    
                    Image(systemName: genisletildi ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
            
            if genisletildi {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(oneriler, id: \.mesajKey) { oneri in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: oneri.ikon)
                                .font(.callout)
                                .foregroundColor(oneri.renk)
                                .frame(width: 24)
                            
                            Text(LocalizedStringKey(oneri.mesajKey))
                                .font(.subheadline)
                                .foregroundColor(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                            
                            Spacer()
                        }
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
}

struct Oneri {
    let ikon: String
    let mesajKey: String
    let renk: Color
}