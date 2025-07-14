//
//  OdemeTakvimiView.swift
//  Walleo
//
//  Created by Mustafa Turan on 14.07.2025.
//


import SwiftUI

struct OdemeTakvimiView: View {
    let odemeTakvimiGunleri: [KrediRaporViewModel.OdemeTakvimGunu]
    @EnvironmentObject var appSettings: AppSettings
    
    @State private var selectedDate: Date?
    @State private var animateCards = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("loan_report.payment_calendar")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 12) {
                    ForEach(Array(odemeTakvimiGunleri.enumerated()), id: \.element.id) { index, gun in
                        TakvimGunuCard(
                            gun: gun,
                            isSelected: selectedDate == gun.tarih,
                            animateCard: animateCards,
                            animationDelay: Double(index) * 0.1
                        ) {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                selectedDate = selectedDate == gun.tarih ? nil : gun.tarih
                            }
                        }
                        .environmentObject(appSettings)
                    }
                }
                .padding(.bottom, 8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                animateCards = true
            }
        }
    }
}

struct TakvimGunuCard: View {
    let gun: KrediRaporViewModel.OdemeTakvimGunu
    let isSelected: Bool
    let animateCard: Bool
    let animationDelay: Double
    let onTap: () -> Void
    
    @EnvironmentObject var appSettings: AppSettings
    @State private var rotation: Double = 0
    @State private var isFlipped = false
    
    private var isOverdue: Bool {
        !gun.taksitler.allSatisfy { $0.odendiMi } && gun.tarih < Date()
    }
    
    private var isPending: Bool {
        !gun.taksitler.allSatisfy { $0.odendiMi } && gun.tarih >= Date()
    }
    
    var body: some View {
        ZStack {
            // Arka yüz
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
                .overlay(
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.largeTitle)
                            .foregroundColor(.green)
                        
                        Text("Tüm taksitler ödendi")
                            .font(.subheadline.bold())
                            .foregroundStyle(.secondary)
                    }
                )
                .opacity(isFlipped ? 1 : 0)
                .rotation3DEffect(
                    .degrees(rotation + 180),
                    axis: (x: 0, y: 1, z: 0)
                )
            
            // Ön yüz
            VStack(spacing: 0) {
                // Tarih başlığı
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(gun.tarih, format: .dateTime.weekday(.wide))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Text(gun.tarih, format: .dateTime.day().month(.wide))
                            .font(.headline.bold())
                    }
                    
                    Spacer()
                    
                    // Durum göstergesi
                    if isOverdue {
                        PulseView(color: .red, size: 12)
                    } else if isPending {
                        GlowView(color: .orange, size: 12)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.green)
                    }
                }
                .padding()
                .background(backgroundGradient)
                
                // Taksit listesi
                VStack(spacing: 8) {
                    ForEach(gun.taksitler, id: \.krediAdi) { taksit in
                        HStack {
                            Circle()
                                .fill(taksit.renk)
                                .frame(width: 8, height: 8)
                            
                            Text(taksit.krediAdi)
                                .font(.subheadline)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            Text(formatCurrency(
                                amount: taksit.tutar,
                                currencyCode: appSettings.currencyCode,
                                localeIdentifier: appSettings.languageCode
                            ))
                            .font(.subheadline.bold())
                            .foregroundColor(taksit.odendiMi ? .green : .primary)
                            
                            Image(systemName: taksit.odendiMi ? "checkmark.circle.fill" : "circle")
                                .font(.caption)
                                .foregroundColor(taksit.odendiMi ? .green : .secondary)
                        }
                    }
                    
                    Divider()
                    
                    // Toplam
                    HStack {
                        Text("Toplam")
                            .font(.subheadline.bold())
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        Text(formatCurrency(
                            amount: gun.toplamTutar,
                            currencyCode: appSettings.currencyCode,
                            localeIdentifier: appSettings.languageCode
                        ))
                        .font(.callout.bold())
                    }
                }
                .padding()
            }
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            .opacity(isFlipped ? 0 : 1)
            .rotation3DEffect(
                .degrees(rotation),
                axis: (x: 0, y: 1, z: 0)
            )
        }
        .onTapGesture {
            if gun.taksitler.allSatisfy({ $0.odendiMi }) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    isFlipped.toggle()
                    rotation += 180
                }
            } else {
                onTap()
            }
        }
        .scaleEffect(animateCard ? 1 : 0.8)
        .opacity(animateCard ? 1 : 0)
        .offset(y: animateCard ? 0 : 20)
        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(animationDelay), value: animateCard)
    }
    
    private var backgroundGradient: some View {
        LinearGradient(
            colors: isOverdue ? [.red.opacity(0.2), .red.opacity(0.1)] :
                    isPending ? [.orange.opacity(0.2), .orange.opacity(0.1)] :
                    [.green.opacity(0.2), .green.opacity(0.1)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// Pulse animasyon view'ı (geciken ödemeler için)
struct PulseView: View {
    let color: Color
    let size: CGFloat
    @State private var animate = false
    
    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.3))
                .frame(width: size * 2, height: size * 2)
                .scaleEffect(animate ? 1.5 : 1)
                .opacity(animate ? 0 : 1)
            
            Circle()
                .fill(color)
                .frame(width: size, height: size)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
                animate = true
            }
        }
    }
}

// Glow animasyon view'ı (yaklaşan ödemeler için)
struct GlowView: View {
    let color: Color
    let size: CGFloat
    @State private var animate = false
    
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .shadow(color: color, radius: animate ? 10 : 5)
            .scaleEffect(animate ? 1.1 : 1)
            .onAppear {
                withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
                    animate = true
                }
            }
    }
}