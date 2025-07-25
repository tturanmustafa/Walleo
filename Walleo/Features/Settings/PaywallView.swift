import SwiftUI
import RevenueCat

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var entitlementManager: EntitlementManager
    @EnvironmentObject var appSettings: AppSettings
    
    @State private var offerings: Offerings?
    @State private var selectedPackage: Package?
    @State private var isLoading = true
    @State private var isPurchasing = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isEligibleForIntro = false // YENİ EKLE
    
    // Animation States
    @State private var logoRotation: Double = 0
    @State private var pulseAnimation: Bool = false
    @State private var selectedFeatureIndex: Int = 0
    @State private var floatingAnimation: Bool = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Animated Gradient Background
                AnimatedGradientBackground()
                
                if isLoading {
                    LoadingView()
                } else {
                    VStack(spacing: 0) {
                        // Ultra Compact Header
                        ultraCompactHeader
                            .padding(.top, 10)
                            .padding(.bottom, 5)
                        
                        // Feature Carousel - No ScrollView
                        featureCarousel
                            .padding(.vertical, 10)
                            .frame(maxHeight: .infinity)
                        
                        // Fixed Bottom Section - More Compact
                        VStack(spacing: 10) {
                            // Packages Section Title
                            Text(LocalizedStringKey("paywall.select_plan"))
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            // Packages in Grid
                            if let offerings = offerings {
                                compactPackagesGrid(offerings)
                            }
                            
                            // CTA Button
                            compactPurchaseButton
                            
                            // Minimal footer
                            minimalFooter
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            Color(.systemBackground)
                                .shadow(color: .black.opacity(0.05), radius: 5, y: -3)
                        )
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    CloseButton { dismiss() }
                }
            }
        }
        .onAppear {
            startAnimations()
            fetchOfferings()
        }
        .onChange(of: selectedPackage) { _, _ in
            // YENİ EKLE: Paket değiştiğinde deneme hakkını yeniden kontrol et
            checkTrialEligibility()
        }
        .alert(LocalizedStringKey("paywall.error.purchase_failed"), isPresented: $showError) {
            Button("common.ok") { }
        } message: {
            Text(errorMessage)
        }
        .onChange(of: entitlementManager.hasPremiumAccess) { _, newValue in
            if newValue {
                dismiss()
            }
        }
    }
    
    // MARK: - Ultra Compact Header
    private var ultraCompactHeader: some View {
        HStack(spacing: 12) {
            // Small Crown Icon
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                Color.yellow.opacity(0.2),
                                Color.clear
                            ]),
                            center: .center,
                            startRadius: 5,
                            endRadius: 20
                        )
                    )
                    .frame(width: 40, height: 40)
                    .blur(radius: 5)
                    .scaleEffect(pulseAnimation ? 1.2 : 1)
                
                Image(systemName: "crown.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [.yellow, .orange]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: .yellow.opacity(0.3), radius: 5)
                    .scaleEffect(pulseAnimation ? 1.1 : 1)
            }
            
            // Title & Subtitle
            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey("paywall.title"))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.purple, Color.pink]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Text(LocalizedStringKey("paywall.subtitle"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.horizontal)
    }
    
    // MARK: - Optimized Feature Carousel
    private var featureCarousel: some View {
        VStack(spacing: 8) {
            // Smaller Feature Cards
            TabView(selection: $selectedFeatureIndex) {
                ForEach(0..<4, id: \.self) { index in
                    CompactFeatureCard(feature: features[index])
                        .tag(index)
                        .padding(.horizontal)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .frame(maxHeight: 270) // Yazılar büyüdüğü için yükseklik artırıldı
            
            // Smaller Page Indicator
            HStack(spacing: 6) {
                ForEach(0..<4, id: \.self) { index in  // 5'ten 4'e değişti
                    Circle()
                        .fill(selectedFeatureIndex == index ? Color.accentColor : Color.gray.opacity(0.3))
                        .frame(width: selectedFeatureIndex == index ? 8 : 6,
                               height: selectedFeatureIndex == index ? 8 : 6)
                        .animation(.spring(), value: selectedFeatureIndex)
                }
            }
        }
    }
    
    // MARK: - Compact Packages Grid (Side by Side)
    private func compactPackagesGrid(_ offerings: Offerings) -> some View {
        HStack(spacing: 10) {
            if let packages = offerings.current?.availablePackages {
                ForEach(packages, id: \.identifier) { package in
                    MiniPackageCard(
                        package: package,
                        packages: packages, // Tüm paketleri gönder
                        isSelected: selectedPackage?.identifier == package.identifier,
                        onTap: {
                            withAnimation(.spring()) {
                                selectedPackage = package
                            }
                        }
                    )
                }
            }
        }
        .frame(maxHeight: 80)
    }
    
    // MARK: - Compact Purchase Button
    private var compactPurchaseButton: some View {
        Button(action: purchase) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.purple, Color.pink]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 44) // Smaller height
                
                if isPurchasing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 16))
                        Text(LocalizedStringKey(purchaseButtonTextKey)) // DEĞIŞTI
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .disabled(selectedPackage == nil || isPurchasing)
        .opacity(selectedPackage == nil ? 0.6 : 1)
    }

    // YENİ EKLE: Buton metni için computed property
    private var purchaseButtonTextKey: String {
        if isEligibleForIntro && selectedPackage?.storeProduct.introductoryDiscount != nil {
            return "paywall.purchase_button" // "Try 3 Days Free"
        } else {
            return "paywall.purchase_button_regular" // Yeni localization key
        }
    }
    
    // MARK: - Minimal Footer
    private var minimalFooter: some View {
        VStack(spacing: 6) {
            Button(LocalizedStringKey("paywall.restore")) {
                restorePurchases()
            }
            .font(.caption)
            .foregroundColor(.secondary)
            
            HStack(spacing: 10) {
                Link(LocalizedStringKey("paywall.privacy"),
                     destination: URL(string: "https://walleo.app/#privacy")!)
                
                Text("•")
                
                Link(LocalizedStringKey("paywall.terms"),
                     destination: URL(string: "https://walleo.app/#terms")!)
            }
            .font(.caption2)
            .foregroundColor(.secondary)
            
            Text(LocalizedStringKey("paywall.subscription_info"))
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .padding(.bottom, 5)
    }
    
    // MARK: - Features Data
    private var features: [PremiumFeature] {
        [
            PremiumFeature(
                icon: "infinity",
                iconColor: .blue,
                titleKey: "paywall.feature.unlimited_accounts.title",
                descriptionKey: "paywall.feature.unlimited_accounts.description",
                detailKey: "paywall.feature.unlimited_accounts.detail"
            ),
            PremiumFeature(
                icon: "square.and.arrow.up.fill",
                iconColor: .green,
                titleKey: "paywall.feature.export.title",
                descriptionKey: "paywall.feature.export.description",
                detailKey: "paywall.feature.export.detail"
            ),
            PremiumFeature(
                icon: "chart.pie.fill",
                iconColor: .orange,
                titleKey: "paywall.feature.budgets.title",
                descriptionKey: "paywall.feature.budgets.description",
                detailKey: "paywall.feature.budgets.detail"
            ),
            PremiumFeature(
                icon: "magnifyingglass.circle.fill",
                iconColor: .purple,
                titleKey: "paywall.feature.reports.title",
                descriptionKey: "paywall.feature.reports.description",
                detailKey: "paywall.feature.reports.detail"
            )
        ]
    }
    
    // MARK: - Animations
    private func startAnimations() {
        withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
            pulseAnimation = true
        }
        
        withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
            floatingAnimation = true
        }
    }
    
    // MARK: - API Methods
    private func fetchOfferings() {
        Purchases.shared.getOfferings { offerings, error in
            if let offerings = offerings {
                self.offerings = offerings
                // Önce yıllık paketi seç, yoksa ilk paketi seç
                if let annualPackage = offerings.current?.availablePackages.first(where: { $0.packageType == .annual }) {
                    self.selectedPackage = annualPackage
                } else if let firstPackage = offerings.current?.availablePackages.first {
                    self.selectedPackage = firstPackage
                }
                
                // YENİ EKLE: Deneme hakkı kontrolü
                self.checkTrialEligibility()
            } else if let error = error {
                self.errorMessage = error.localizedDescription
                self.showError = true
            }
            self.isLoading = false
        }
    }

    // YENİ EKLE: Deneme hakkı kontrol fonksiyonu
    private func checkTrialEligibility() {
        guard let selectedPackage = selectedPackage else { return }
        
        // RevenueCat ile deneme hakkı kontrolü
        Purchases.shared.checkTrialOrIntroDiscountEligibility(productIdentifiers: [selectedPackage.storeProduct.productIdentifier]) { eligibility in
            if let status = eligibility[selectedPackage.storeProduct.productIdentifier] {
                self.isEligibleForIntro = (status.status == .eligible)
            } else {
                self.isEligibleForIntro = false
            }
        }
    }
    
    private func purchase() {
        guard let package = selectedPackage else { return }
        
        isPurchasing = true
        
        Purchases.shared.purchase(package: package) { transaction, customerInfo, error, userCancelled in
            isPurchasing = false
            
            if let error = error, !userCancelled {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
    
    private func restorePurchases() {
        isPurchasing = true
        
        Purchases.shared.restorePurchases { customerInfo, error in
            isPurchasing = false
            
            if let error = error {
                errorMessage = error.localizedDescription
                showError = true
            } else if customerInfo?.entitlements["Premium"]?.isActive == true {
                // Success - will auto dismiss
            } else {
                errorMessage = NSLocalizedString("paywall.error.no_purchases", comment: "")
                showError = true
            }
        }
    }
}

// MARK: - Feature Model
struct PremiumFeature {
    let icon: String
    let iconColor: Color
    let titleKey: String
    let descriptionKey: String
    let detailKey: String
}

// MARK: - Compact Feature Card (Smaller)
struct CompactFeatureCard: View {
    let feature: PremiumFeature
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 12) {
            // Smaller Icon
            ZStack {
                Circle()
                    .fill(feature.iconColor.opacity(0.15))
                    .frame(width: 56, height: 56) // 50'den 56'ya
                
                Image(systemName: feature.icon)
                    .font(.system(size: 28)) // 24'ten 28'e
                    .foregroundColor(feature.iconColor)
            }
            
            // Compact Content
            VStack(spacing: 6) {
                Text(LocalizedStringKey(feature.titleKey))
                    .font(.system(size: 25, weight: .semibold)) // Biraz daha büyük
                
                Text(LocalizedStringKey(feature.descriptionKey))
                    .font(.system(size: 20, weight: .medium)) // Biraz daha büyük
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                Text(LocalizedStringKey(feature.detailKey))
                    .font(.system(size: 15)) // caption'dan biraz daha büyük
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .padding(.horizontal, 10)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }
}

// MARK: - Mini Package Card (Side by Side)
struct MiniPackageCard: View {
    let package: Package
    let packages: [Package] // Yeni parametre
    let isSelected: Bool
    let onTap: () -> Void
    @EnvironmentObject var appSettings: AppSettings
    
    private var priceString: String {
        package.storeProduct.localizedPriceString
    }
    
    private var periodString: String {
        // Uygulama dilini kullan
        let languageBundle = Bundle.getLanguageBundle(for: appSettings.languageCode)
        
        switch package.packageType {
        case .monthly:
            return languageBundle.localizedString(forKey: "paywall.monthly", value: "", table: nil)
        case .annual:
            return languageBundle.localizedString(forKey: "paywall.yearly", value: "", table: nil)
        case .weekly:
            return languageBundle.localizedString(forKey: "paywall.weekly", value: "", table: nil)
        default:
            return ""
        }
    }
    
    // Tasarruf yüzdesini hesapla
    private func calculateSavingsPercentage() -> String? {
        guard package.packageType == .annual,
              let monthlyPackage = packages.first(where: { $0.packageType == .monthly }),
              let annualPackage = packages.first(where: { $0.packageType == .annual }) else {
            return nil
        }
        
        let monthlyPrice = (monthlyPackage.storeProduct.price as NSDecimalNumber).doubleValue
        let annualPrice = (annualPackage.storeProduct.price as NSDecimalNumber).doubleValue
        
        guard monthlyPrice > 0, annualPrice > 0 else { return nil }
        
        // 12 aylık toplam maliyet
        let yearlyTotal = monthlyPrice * 12
        
        // Tasarruf
        let savings = yearlyTotal - annualPrice
        
        // Yüzde hesapla
        let percentage = (savings / yearlyTotal) * 100
        
        // 2 ondalık basamağa kes (yuvarlama değil)
        let truncated = floor(percentage * 100) / 100
        
        // Locale ayarlarına göre formatla
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: appSettings.languageCode)
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        
        // Gereksiz sıfırları kaldır (örn: 50.00 -> 50, 49.90 -> 49.9)
        if let formattedNumber = formatter.string(from: NSNumber(value: truncated)) {
            // Uygulama dilini kullan
            let languageBundle = Bundle.getLanguageBundle(for: appSettings.languageCode)
            let format = languageBundle.localizedString(forKey: "paywall.save_percent", value: "", table: nil)
            return String(format: format, formattedNumber)
        }
        
        return nil
    }
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: isSelected ? [
                                Color.purple.opacity(0.15),
                                Color.pink.opacity(0.15)
                            ] : [
                                Color(.systemGray6),
                                Color(.systemGray6)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.purple : Color.clear, lineWidth: 2)
                    )
                
                VStack(spacing: 4) {
                    Text(periodString)
                        .font(.caption)
                        .fontWeight(.semibold)
                    
                    Text(priceString)
                        .font(.headline)
                        .fontWeight(.bold)
                    
                    if let savingsText = calculateSavingsPercentage() {
                        Text(savingsText)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.green)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 10)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Supporting Views
struct AnimatedGradientBackground: View {
    @State private var animateGradient = false
    
    var body: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(hex: "667eea"),
                Color(hex: "764ba2"),
                Color(hex: "f093fb")
            ]),
            startPoint: animateGradient ? .topLeading : .bottomLeading,
            endPoint: animateGradient ? .bottomTrailing : .topTrailing
        )
        .ignoresSafeArea()
        .opacity(0.1)
        .onAppear {
            withAnimation(.linear(duration: 10).repeatForever(autoreverses: true)) {
                animateGradient.toggle()
            }
        }
    }
}

struct LoadingView: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "crown.fill")
                .font(.system(size: 60))
                .foregroundColor(.yellow)
                .rotationEffect(.degrees(isAnimating ? 360 : 0))
                .onAppear {
                    withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                        isAnimating = true
                    }
                }
            
            ProgressView()
                .scaleEffect(1.5)
        }
    }
}

struct CloseButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 30, height: 30)
                
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.secondary)
            }
        }
    }
}
