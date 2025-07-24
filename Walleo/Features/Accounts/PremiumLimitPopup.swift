//
//  PremiumLimitPopup.swift
//  Walleo
//
//  Created by Mustafa Turan on 24.07.2025.
//


// YENİ DOSYA: Walleo/Features/Accounts/Views/PremiumLimitPopup.swift

import SwiftUI

struct PremiumLimitPopup: View {
    @Binding var isPresented: Bool
    let hesapTuru: HesapTuru?
    let onContinue: () -> Void
    
    @State private var animateIcon = false
    @State private var animateContent = false
    @State private var pulseAnimation = false
    
    private var hesapTuruAdi: LocalizedStringKey {
        switch hesapTuru {
        case .cuzdan:
            return "accounts.type.wallet"
        case .krediKarti:
            return "accounts.type.credit_card"
        case .kredi:
            return "accounts.type.loan"
        case .none:
            return "accounts.type.account"
        }
    }
    
    var body: some View {
        ZStack {
            // Arka plan blur efekti
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    // Arka plana tıklanınca kapatma
                }
            
            // Ana içerik
            VStack(spacing: 24) {
                // Animasyonlu Crown Icon
                ZStack {
                    // Pulse efekti için arka plan
                    Circle()
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [
                                    Color.yellow.opacity(0.3),
                                    Color.clear
                                ]),
                                center: .center,
                                startRadius: 10,
                                endRadius: 60
                            )
                        )
                        .frame(width: 120, height: 120)
                        .scaleEffect(pulseAnimation ? 1.3 : 0.8)
                        .opacity(pulseAnimation ? 0 : 0.8)
                    
                    // Ana ikon container
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.yellow, Color.orange]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 80, height: 80)
                            .shadow(color: .yellow.opacity(0.5), radius: 20)
                        
                        Image(systemName: "crown.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.white)
                            .rotationEffect(.degrees(animateIcon ? 0 : -15))
                            .scaleEffect(animateIcon ? 1 : 0.8)
                    }
                    .scaleEffect(animateIcon ? 1 : 0)
                }
                
                // İçerik
                VStack(spacing: 16) {
                    // Başlık
                    Text("premium.limit.title")
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    // Açıklama
                    VStack(spacing: 12) {
                        Text("premium.limit.subtitle")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        // Limit bilgisi
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(.orange)
                            
                            Text("premium.limit.info")
                                .font(.callout)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(12)
                    }
                }
                .opacity(animateContent ? 1 : 0)
                .offset(y: animateContent ? 0 : 20)
                
                // Butonlar
                VStack(spacing: 12) {
                    // Premium'a Geç butonu
                    Button(action: {
                        isPresented = false
                        onContinue()
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 18))
                            
                            Text("premium.limit.button")
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.purple, Color.pink]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(16)
                        .shadow(color: .purple.opacity(0.3), radius: 10, y: 5)
                    }
                    .scaleEffect(animateContent ? 1 : 0.9)
                    .opacity(animateContent ? 1 : 0)
                    
                    // İptal butonu
                    Button(action: {
                        isPresented = false
                    }) {
                        Text("common.cancel")
                            .foregroundColor(.secondary)
                            .font(.callout)
                    }
                    .opacity(animateContent ? 1 : 0)
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.2), radius: 20)
            )
            .padding(.horizontal, 32)
            .scaleEffect(animateContent ? 1 : 0.8)
            .opacity(animateContent ? 1 : 0)
        }
        .onAppear {
            startAnimations()
        }
    }
    
    private func startAnimations() {
        // İkon animasyonu
        withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
            animateIcon = true
        }
        
        // İkon rotasyon animasyonu
        withAnimation(.easeInOut(duration: 0.8).delay(0.3)) {
            animateIcon = true
        }
        
        // İçerik animasyonu
        withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.2)) {
            animateContent = true
        }
        
        // Sürekli pulse animasyonu
        withAnimation(.easeOut(duration: 1.5).repeatForever(autoreverses: false)) {
            pulseAnimation = true
        }
    }
}