//
//  FloatingSymbol.swift
//  Walleo
//
//  Created by Mustafa Turan on 4.07.2025.
//


import SwiftUI
import AuthenticationServices // Apple ile Giriş için gerekli
import SwiftData // <-- BU SATIRI EKLEYİN


// --- 1. MODELLER VE LOKALİZE EDİLMİŞ VERİLER ---

struct FloatingSymbol: Identifiable {
    let id = UUID()
    let symbolName: String, size: CGFloat, opacity: Double, animationDuration: Double
    let startPoint: UnitPoint, endPoint: UnitPoint
}

struct OnboardingPage: Identifiable {
    let id = UUID()
    let titleKey: LocalizedStringKey
    let subtitleKey: LocalizedStringKey
}

let onboardingPages: [OnboardingPage] = [
    .init(titleKey: "onboarding.page1.title", subtitleKey: "onboarding.page1.subtitle"),
    .init(titleKey: "onboarding.page2.title", subtitleKey: "onboarding.page2.subtitle"),
    .init(titleKey: "onboarding.page3.title", subtitleKey: "onboarding.page3.subtitle"),
    .init(titleKey: "onboarding.page4.title", subtitleKey: "onboarding.page4.subtitle"),
    .init(titleKey: "onboarding.page5.title", subtitleKey: "onboarding.page5.subtitle"),
    .init(titleKey: "onboarding.page6.title", subtitleKey: "onboarding.page6.subtitle")
]

// --- 2. ANA ONBOARDING EKRANI ---

struct OnboardingView: View {
    @EnvironmentObject var appSettings: AppSettings
    @Environment(\.modelContext) private var modelContext

    
    var body: some View {
        ZStack {
            AnimatedBackgroundView().ignoresSafeArea()

            VStack {
                // Logo
                Image("app_logo_onboarding") // Not: Kendi logonuzla değiştirin -> Image("app-logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80)
                    .foregroundColor(.white)
                    .padding(.top, 20)

                Spacer()
                
                // Ana Görsel
                Image("text_logo_onboarding") // Not: Kendi görselinizle değiştirin -> Image("feature-illustration")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 300)
                    .foregroundColor(.white.opacity(0.8))
                    .padding()

                // Kaydırılabilir Metin Alanı
                TabView {
                    ForEach(onboardingPages) { page in
                        PagedTextView(page: page)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .frame(height: 200)
                
                Spacer()
                
                // --- YENİ KOD: APPLE İLE GİRİŞ BUTONU ---
                VStack(spacing: 15) {
                    SignInWithAppleButton(
                        .signIn,
                        onRequest: { request in
                            request.requestedScopes = [.fullName, .email]
                        },
                        onCompletion: { result in
                            switch result {
                            case .success(let authorization):
                                if let _ = authorization.credential as? ASAuthorizationAppleIDCredential {
                                    
                                    let preferredLanguage = Locale.preferredLanguages.first ?? "en"
                                    // Eğer dil "tr" ile başlıyorsa, uygulama dilini Türkçe yap.
                                    if preferredLanguage.lowercased().starts(with: "tr") {
                                        appSettings.languageCode = "tr"
                                    } else {
                                        // Değilse, İngilizce yap.
                                        appSettings.languageCode = "en"
                                    }
                                    
                                    // --- DİKKAT: EN ÖNEMLİ DEĞİŞİKLİK BURADA ---
                                    // 1. Giriş başarılı olduğu anda ilk verileri oluştur.
                                    seedInitialData()
                                    
                                    // 2. Veriler oluşturulduktan sonra, ana ekrana geçişi onayla.
                                    appSettings.hasCompletedOnboarding = true
                                }
                            case .failure(let error):
                                Logger.log("Apple ile Giriş Başarısız: \(error.localizedDescription)", log: Logger.service, type: .error)
                            }
                        }
                    )
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 55)
                    .cornerRadius(12)
                    
                    Text(LocalizedStringKey("onboarding.privacy_policy"))
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 20)
            }
            .padding(.vertical)
        }
    }
    
    // YENİ FONKSİYON: İlk verileri oluşturan ana mantık
    private func seedInitialData() {
        do {
            let descriptor = FetchDescriptor<AppMetadata>()
            if let metadata = try modelContext.fetch(descriptor).first, metadata.defaultCategoriesAdded {
                return
            }
            
            let categoryDescriptor = FetchDescriptor<Kategori>()
            let existingCategoriesCount = try modelContext.fetchCount(categoryDescriptor)
            
            if existingCategoriesCount == 0 {
                Logger.log("Onboarding başarılı. Veritabanı boş. Varsayılan kategoriler ekleniyor...", log: Logger.service, type: .info)
                
                modelContext.insert(Kategori(isim: "Maaş", ikonAdi: "dollarsign.circle.fill", tur: .gelir, renkHex: "#34C759", localizationKey: "category.salary"))
                modelContext.insert(Kategori(isim: "Ek Gelir", ikonAdi: "chart.pie.fill", tur: .gelir, renkHex: "#007AFF", localizationKey: "category.extra_income"))
                modelContext.insert(Kategori(isim: "Yatırım", ikonAdi: "chart.line.uptrend.xyaxis", tur: .gelir, renkHex: "#AF52DE", localizationKey: "category.investment"))
                modelContext.insert(Kategori(isim: "Market", ikonAdi: "cart.fill", tur: .gider, renkHex: "#FF9500", localizationKey: "category.groceries"))
                modelContext.insert(Kategori(isim: "Restoran", ikonAdi: "fork.knife", tur: .gider, renkHex: "#FF3B30", localizationKey: "category.restaurant"))
                modelContext.insert(Kategori(isim: "Ulaşım", ikonAdi: "car.fill", tur: .gider, renkHex: "#5E5CE6", localizationKey: "category.transport"))
                modelContext.insert(Kategori(isim: "Faturalar", ikonAdi: "bolt.fill", tur: .gider, renkHex: "#FFCC00", localizationKey: "category.bills"))
                modelContext.insert(Kategori(isim: "Eğlence", ikonAdi: "film.fill", tur: .gider, renkHex: "#32ADE6", localizationKey: "category.entertainment"))
                modelContext.insert(Kategori(isim: "Sağlık", ikonAdi: "pills.fill", tur: .gider, renkHex: "#64D2FF", localizationKey: "category.health"))
                modelContext.insert(Kategori(isim: "Giyim", ikonAdi: "tshirt.fill", tur: .gider, renkHex: "#FF2D55", localizationKey: "category.clothing"))
                modelContext.insert(Kategori(isim: "Ev", ikonAdi: "house.fill", tur: .gider, renkHex: "#A2845E", localizationKey: "category.home"))
                modelContext.insert(Kategori(isim: "Hediye", ikonAdi: "gift.fill", tur: .gider, renkHex: "#BF5AF2", localizationKey: "category.gift"))
                modelContext.insert(Kategori(isim: "Kredi Ödemesi", ikonAdi: "creditcard.and.123", tur: .gider, renkHex: "#8E8E93", localizationKey: "category.loan_payment"))
                modelContext.insert(Kategori(isim: "Diğer", ikonAdi: "ellipsis.circle.fill", tur: .gider, renkHex: "#8E8E93", localizationKey: "category.other"))
            }

            let metadataDescriptor = FetchDescriptor<AppMetadata>()
            if let metadataToUpdate = try modelContext.fetch(metadataDescriptor).first {
                metadataToUpdate.defaultCategoriesAdded = true
            } else {
                let newMetadata = AppMetadata(defaultCategoriesAdded: true)
                modelContext.insert(newMetadata)
            }
            
            try modelContext.save()
            Logger.log("Onboarding: İlk veri kurulumu başarıyla kaydedildi.", log: Logger.service, type: .info)
            
        } catch {
            Logger.log("Onboarding: İlk veri kurulumunda KRİTİK HATA: \(error.localizedDescription)", log: Logger.data, type: .fault)
        }
    }
}

// --- 3. YARDIMCI GÖRÜNÜMLER ---

struct AnimatedBackgroundView: View {
    @State private var symbols: [FloatingSymbol] = []
    @State private var move = false

    private let symbolNames = [
        "turkishlirasign.circle.fill", "dollarsign.circle.fill", "eurosign.circle.fill",
        "sterlingsign.circle.fill", "yensign.circle.fill", "indianrupeesign.circle.fill",
        "rublesign.circle.fill", "wonsign.circle.fill", "plus.circle.fill", "minus.circle.fill"
    ]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(hex: "001C1F").ignoresSafeArea()
                ForEach(symbols) { symbol in
                    Image(systemName: symbol.symbolName)
                        .resizable().scaledToFit().frame(width: symbol.size, height: symbol.size)
                        .foregroundColor(Color(hex: "B1F7FF")).opacity(symbol.opacity)
                        .position(
                            x: (move ? symbol.endPoint.x : symbol.startPoint.x) * geometry.size.width,
                            y: (move ? symbol.endPoint.y : symbol.startPoint.y) * geometry.size.height
                        )
                        .animation(
                            Animation.linear(duration: symbol.animationDuration)
                                .repeatForever(autoreverses: true).delay(.random(in: 0...1.5)),
                            value: move
                        )
                }
            }
        }
        .onAppear {
            setupSymbols()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { move = true }
        }
    }
    
    private func setupSymbols() {
        guard symbols.isEmpty else { return }
        for _ in 0..<25 {
            symbols.append(
                FloatingSymbol(
                    symbolName: symbolNames.randomElement()!,
                    size: .random(in: 15...35),
                    opacity: .random(in: 0.05...0.2),
                    animationDuration: .random(in: 8...20),
                    startPoint: UnitPoint(x: .random(in: 0...1), y: .random(in: 0...1)),
                    endPoint: UnitPoint(x: .random(in: 0...1), y: .random(in: 0...1))
                )
            )
        }
    }
}

struct PagedTextView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 15) {
            Text(page.titleKey)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)

            Text(page.subtitleKey)
                .font(.system(size: 16, weight: .regular, design: .default))
                .multilineTextAlignment(.center)
                .foregroundColor(.white.opacity(0.8))
                .lineSpacing(5)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 20)
    }
}
