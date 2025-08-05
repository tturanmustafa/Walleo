import SwiftUI
import SwiftData

// MARK: - Ana Onboarding View
struct OnboardingView: View {
    @EnvironmentObject var appSettings: AppSettings
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var currentPage = 0
    @State private var selectedLanguage: String = ""
    @State private var selectedCurrency: String = ""
    @State private var showContent = false
    
    // Animasyon state'leri
    @State private var logoScale: CGFloat = 0.8
    @State private var contentOpacity: Double = 0
    
    // Sayfa sayıları güncellendi
    let welcomeAndFeaturePages = 6 // Welcome + 5 özellik
    let personalizationPage = 6
    let totalPages = 7
    
    init() {
        // Dil seçimi - Kullanıcının tercih ettiği dillerden ilkini al
        let preferredLanguage = Locale.preferredLanguages.first ?? "en"
        let languageCode = String(preferredLanguage.prefix(2))
        
        // Desteklenen diller listesi
        let supportedLanguages = ["tr", "en", "de", "fr", "es", "it", "ja", "zh", "id", "hi", "vi", "th", "ms"]
        
        if supportedLanguages.contains(languageCode) {
            _selectedLanguage = State(initialValue: languageCode)
        } else {
            _selectedLanguage = State(initialValue: "en")
        }
        
        // Para birimi seçimi - Ülke koduna göre
        let locale = Locale.current
        let regionCode = locale.region?.identifier ?? ""
        
        let defaultCurrency: String = switch regionCode {
            // Europe - Euro Zone
            case "AT", "BE", "CY", "EE", "FI", "FR", "DE", "GR", "IE", "IT", "LV", "LT", "LU", "MT", "NL", "PT", "SK", "SI", "ES": "EUR"
            
            // Americas
            case "US": "USD"
            case "CA": "CAD"
            case "MX": "MXN"
            case "BR": "BRL"
            case "AR": "ARS"
            case "CL": "CLP"
            case "CO": "COP"
            case "PE": "PEN"
            case "UY": "UYU"
            case "PY": "PYG"
            case "BO": "BOB"
            case "VE": "VES"
            case "CR": "CRC"
            case "GT": "GTQ"
            case "HN": "HNL"
            case "NI": "NIO"
            case "PA": "PAB"
            case "DO": "DOP"
            case "JM": "JMD"
            case "TT": "TTD"
            case "BB": "BBD"
            case "BS": "BSD"
            case "HT": "HTG"
            
            // Asia
            case "JP": "JPY"
            case "CN": "CNY"
            case "IN": "INR"
            case "ID": "IDR"
            case "MY": "MYR"
            case "SG": "SGD"
            case "TH": "THB"
            case "VN": "VND"
            case "PH": "PHP"
            case "KR": "KRW"
            case "HK": "HKD"
            case "TW": "TWD"
            case "PK": "PKR"
            case "BD": "BDT"
            case "LK": "LKR"
            case "NP": "NPR"
            case "MM": "MMK"
            case "LA": "LAK"
            case "KH": "KHR"
            case "BN": "BND"
            
            // Middle East & Africa
            case "AE": "AED"
            case "SA": "SAR"
            case "QA": "QAR"
            case "OM": "OMR"
            case "BH": "BHD"
            case "KW": "KWD"
            case "JO": "JOD"
            case "IL": "ILS"
            case "EG": "EGP"
            case "MA": "MAD"
            case "TN": "TND"
            case "DZ": "DZD"
            case "ZA": "ZAR"
            case "KE": "KES"
            case "UG": "UGX"
            case "TZ": "TZS"
            case "ET": "ETB"
            case "GH": "GHS"
            case "NG": "NGN"
            
            // Europe (Non-Euro)
            case "GB": "GBP"
            case "CH": "CHF"
            case "SE": "SEK"
            case "NO": "NOK"
            case "DK": "DKK"
            case "IS": "ISK"
            case "PL": "PLN"
            case "CZ": "CZK"
            case "HU": "HUF"
            case "RO": "RON"
            case "BG": "BGN"
            case "HR": "HRK"
            case "RS": "RSD"
            case "MK": "MKD"
            case "AL": "ALL"
            case "BA": "BAM"
            case "UA": "UAH"
            case "BY": "BYN"
            case "MD": "MDL"
            case "GE": "GEL"
            case "AM": "AMD"
            case "AZ": "AZN"
            
            // Turkey & Central Asia
            case "TR": "TRY"
            case "KZ": "KZT"
            case "UZ": "UZS"
            case "KG": "KGS"
            case "TJ": "TJS"
            case "TM": "TMT"
            case "AF": "AFN"
            case "MN": "MNT"
            
            // Pacific
            case "AU": "AUD"
            case "NZ": "NZD"
            case "FJ": "FJD"
            case "PG": "PGK"
            case "SB": "SBD"
            case "TO": "TOP"
            case "VU": "VUV"
            case "WS": "WST"
            
            // Others
            case "RU": "RUB"
            case "IR": "IRR"
            case "IQ": "IQD"
            case "SY": "SYP"
            case "YE": "YER"
            case "LB": "LBP"
            case "MZ": "MZN"
            case "AO": "AOA"
            case "MG": "MGA"
            case "MU": "MUR"
            case "SC": "SCR"
            case "MV": "MVR"
            case "BT": "BTN"
            
            // West & Central Africa CFA zones
            case "BJ", "BF", "CI", "GW", "ML", "NE", "SN", "TG": "XOF"
            case "CM", "CF", "TD", "CG", "GQ", "GA": "XAF"
            
            // East Caribbean Dollar zone
            case "AG", "DM", "GD", "KN", "LC", "VC": "XCD"
            
            // French Pacific territories
            case "NC", "PF", "WF": "XPF"
            
            default: "USD"
        }
        
        _selectedCurrency = State(initialValue: defaultCurrency)
    }
    
    var body: some View {
        ZStack {
            // Gradient arka plan
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(hex: colorScheme == .dark ? "0A2342" : "E8F4FD"),
                    Color(hex: colorScheme == .dark ? "001C3D" : "D1E9F6")
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Ana içerik
            VStack(spacing: 10) { // spacing optimize edildi
                // Skip butonu - sadece welcome ve feature sayfalarında göster
                HStack {
                    Spacer()
                    if currentPage < personalizationPage {
                        Button(action: {
                            withAnimation {
                                currentPage = personalizationPage
                            }
                        }) {
                            Text(LocalizedStringKey("onboarding.skip"))
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(20)
                        }
                        .padding()
                        .opacity(contentOpacity)
                    }
                }
                
                // Logo
                Image("app_logo_onboarding")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .scaleEffect(logoScale)
                    .padding(.top, -10) // Yukarıya aldık
                
                // İçerik alanı
                TabView(selection: $currentPage) {
                    WelcomePage()
                        .tag(0)
                    
                    AllInOneFeaturePage()
                        .tag(1)
                    
                    SmartBudgetFeaturePage()
                        .tag(2)
                    
                    InsightfulReportsFeaturePage()
                        .tag(3)
                    
                    IntelligentCategorizationFeaturePage()
                        .tag(4)
                    
                    SecureBackupFeaturePage()
                        .tag(5)
                    
                    PersonalizationPage(
                        selectedLanguage: $selectedLanguage,
                        selectedCurrency: $selectedCurrency,
                        onComplete: {
                            seedInitialData()
                        }
                    )
                    .tag(6)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .opacity(contentOpacity)
                .padding(.top, -30) // TabView'i yukarı aldık
                
                // Alt kontroller
                VStack(spacing: 15) { // spacing azaltıldı
                    // Page indicator
                    if currentPage < totalPages - 1 {
                        PageIndicator(currentPage: currentPage, totalPages: totalPages)
                            .padding(.bottom, 5) // padding azaltıldı
                    }
                    
                    // Action button - sadece personalization sayfası hariç
                    if currentPage < personalizationPage {
                        Button(action: nextPage) {
                            Text(LocalizedStringKey("onboarding.continue"))
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.accentColor)
                                .cornerRadius(16)
                        }
                        .padding(.horizontal, 30)
                    }
                }
                .padding(.bottom, 20)
                .opacity(contentOpacity)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                logoScale = 1.0
                contentOpacity = 1.0
            }
        }
    }
    
    private func nextPage() {
        withAnimation(.spring()) {
            currentPage += 1
        }
    }
    
    private func seedInitialData() {
        do {
            // Transaction başlat
            try modelContext.save()
            
            // ÇÖZÜM 1: CloudKit senkronizasyonunun tamamlanmasını bekle
            Thread.sleep(forTimeInterval: 0.5)
            
            // Metadata kontrolü
            let metadataDescriptor = FetchDescriptor<AppMetadata>()
            let existingMetadata = try modelContext.fetch(metadataDescriptor).first
            
            // Mevcut kategorileri kontrol et
            let categoryDescriptor = FetchDescriptor<Kategori>()
            let existingCategories = try modelContext.fetch(categoryDescriptor)
            
            Logger.log("Mevcut kategori sayısı: \(existingCategories.count)", log: Logger.data)
            
            // Sistem kategorilerini tanımla
            let systemCategories: [(isim: String, ikonAdi: String, tur: IslemTuru, renkHex: String, localizationKey: String)] = [
                ("Maaş", "dollarsign.circle.fill", .gelir, "#34C759", "category.salary"),
                ("Ek Gelir", "chart.pie.fill", .gelir, "#007AFF", "category.extra_income"),
                ("Yatırım", "chart.line.uptrend.xyaxis", .gelir, "#AF52DE", "category.investment"),
                ("Market", "cart.fill", .gider, "#FF9500", "category.groceries"),
                ("Restoran", "fork.knife", .gider, "#FF3B30", "category.restaurant"),
                ("Ulaşım", "car.fill", .gider, "#5E5CE6", "category.transport"),
                ("Faturalar", "bolt.fill", .gider, "#FFCC00", "category.bills"),
                ("Eğlence", "film.fill", .gider, "#32ADE6", "category.entertainment"),
                ("Sağlık", "pills.fill", .gider, "#64D2FF", "category.health"),
                ("Giyim", "tshirt.fill", .gider, "#FF2D55", "category.clothing"),
                ("Ev", "house.fill", .gider, "#A2845E", "category.home"),
                ("Hediye", "gift.fill", .gider, "#BF5AF2", "category.gift"),
                ("Kredi Ödemesi", "creditcard.and.123", .gider, "#8E8E93", "category.loan_payment"),
                ("Diğer", "ellipsis.circle.fill", .gider, "#30B0C7", "category.other")
            ]
            
            // ÇÖZÜM 2: Daha güvenli kategori kontrolü
            var kategorilerEklendi = false
            
            for systemCat in systemCategories {
                // Önce localizationKey ile kontrol et
                let existsWithKey = existingCategories.contains { cat in
                    cat.localizationKey == systemCat.localizationKey
                }
                
                // Sonra isim + tür kombinasyonu ile kontrol et (CloudKit'ten gelen eski veriler için)
                let existsWithNameAndType = existingCategories.contains { cat in
                    cat.isim == systemCat.isim && cat.tur == systemCat.tur
                }
                
                if existsWithKey {
                    Logger.log("Sistem kategorisi zaten var (key ile): \(systemCat.localizationKey)", log: Logger.data)
                } else if existsWithNameAndType {
                    // İsim ve tür aynı ama localizationKey yok - güncelle
                    if let existingCat = existingCategories.first(where: {
                        $0.isim == systemCat.isim && $0.tur == systemCat.tur && $0.localizationKey == nil
                    }) {
                        existingCat.localizationKey = systemCat.localizationKey
                        kategorilerEklendi = true
                        Logger.log("Mevcut kategoriye localizationKey eklendi: \(systemCat.isim)", log: Logger.data)
                    }
                } else {
                    // Kategori hiç yok, ekle
                    let newCategory = Kategori(
                        isim: systemCat.isim,
                        ikonAdi: systemCat.ikonAdi,
                        tur: systemCat.tur,
                        renkHex: systemCat.renkHex,
                        localizationKey: systemCat.localizationKey
                    )
                    modelContext.insert(newCategory)
                    kategorilerEklendi = true
                    Logger.log("Yeni sistem kategorisi eklendi: \(systemCat.isim)", log: Logger.data)
                }
            }
            
            // ÇÖZÜM 3: Duplike kategorileri temizle
            cleanupDuplicateCategories(existingCategories: existingCategories)
            
            // Metadata güncelle
            if existingMetadata == nil {
                let newMetadata = AppMetadata(defaultCategoriesAdded: true)
                modelContext.insert(newMetadata)
                kategorilerEklendi = true
            } else {
                existingMetadata!.defaultCategoriesAdded = true
            }
            
            if kategorilerEklendi || existingMetadata == nil {
                try modelContext.save()
                Logger.log("Initial data setup tamamlandı", log: Logger.data)
            }
            
        } catch {
            Logger.log("Initial data setup error: \(error.localizedDescription)", log: Logger.data, type: .fault)
        }
    }
    
    // Yeni yardımcı fonksiyon - duplike kategorileri temizle
    private func cleanupDuplicateCategories(existingCategories: [Kategori]) {
        var seenCategories: [String: Kategori] = [:]
        var duplicatesToDelete: [Kategori] = []
        
        for category in existingCategories {
            // Sistem kategorileri için localizationKey'i kontrol et
            if let locKey = category.localizationKey, !locKey.isEmpty {
                if let existing = seenCategories[locKey] {
                    // Duplike bulundu - eskisini sil
                    Logger.log("Duplike sistem kategorisi bulundu: \(locKey)", log: Logger.data)
                    duplicatesToDelete.append(existing)
                }
                seenCategories[locKey] = category
            } else {
                // Kullanıcı kategorileri için isim + tür kombinasyonunu kontrol et
                let key = "\(category.isim)-\(category.turRawValue)"
                if let existing = seenCategories[key] {
                    // Duplike bulundu - eskisini sil
                    Logger.log("Duplike kullanıcı kategorisi bulundu: \(key)", log: Logger.data)
                    duplicatesToDelete.append(existing)
                }
                seenCategories[key] = category
            }
        }
        
        // Duplikleri sil
        for duplicate in duplicatesToDelete {
            modelContext.delete(duplicate)
            Logger.log("Duplike kategori silindi: \(duplicate.isim)", log: Logger.data)
        }
    }
}

// MARK: - Welcome Page
struct WelcomePage: View {
    @State private var animateElements = false
    
    var body: some View {
        VStack(spacing: 30) { // spacing eski haline döndü
            // Animated Financial Hub Visual
            WelcomeAnimatedVisual()
                .frame(height: 200)
                .scaleEffect(animateElements ? 1 : 0.8)
                .opacity(animateElements ? 1 : 0)
                .padding(.top, -50) // Sadece görsel yukarıda
            
            Text(LocalizedStringKey("onboarding.welcome.title"))
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .offset(y: animateElements ? 0 : 20)
                .opacity(animateElements ? 1 : 0)
            
            Text(LocalizedStringKey("onboarding.welcome.subtitle"))
                .font(.title3)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .offset(y: animateElements ? 0 : 20)
                .opacity(animateElements ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.2)) {
                animateElements = true
            }
        }
    }
}

// MARK: - Welcome Animated Visual
struct WelcomeAnimatedVisual: View {
    @State private var rotationAngle: Double = 0
    @State private var transactionScale: CGFloat = 0
    @State private var transferArrowOffset: CGFloat = -30
    @State private var budgetProgress: CGFloat = 0
    @State private var creditCardFlip: Double = 0
    @State private var installmentStep: Int = 0
    @State private var recurringPulse: CGFloat = 1
    
    var body: some View {
        ZStack {
            // Central Hub Circle
            Circle()
                .stroke(Color.accentColor.opacity(0.2), lineWidth: 2)
                .frame(width: 140, height: 140)
            
            // Rotating Background Pattern
            ForEach(0..<6) { index in
                Circle()
                    .fill(Color.accentColor.opacity(0.05))
                    .frame(width: 30, height: 30)
                    .offset(x: 0, y: -70)
                    .rotationEffect(.degrees(Double(index) * 60 + rotationAngle))
            }
            
            // 1. Transaction Entry Animation (Top)
            VStack(spacing: 4) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.green.opacity(0.1))
                        .frame(width: 60, height: 40)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text("₺150")
                            .font(.caption2)
                            .fontWeight(.medium)
                    }
                }
                .scaleEffect(transactionScale)
                
                Image(systemName: "arrow.down")
                    .font(.caption)
                    .foregroundColor(.green)
                    .opacity(transactionScale)
            }
            .offset(y: -90)
            
            // 2. Transfer Animation (Right)
            HStack(spacing: 15) {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 35, height: 35)
                    .overlay(
                        Image(systemName: "wallet.pass")
                            .font(.caption)
                            .foregroundColor(.blue)
                    )
                
                Image(systemName: "arrow.right")
                    .font(.caption)
                    .foregroundColor(.blue)
                    .offset(x: transferArrowOffset)
                
                Circle()
                    .fill(Color.purple.opacity(0.2))
                    .frame(width: 35, height: 35)
                    .overlay(
                        Image(systemName: "creditcard")
                            .font(.caption)
                            .foregroundColor(.purple)
                    )
            }
            .offset(x: 90, y: 0)
            
            // 3. Budget Progress (Bottom)
            VStack(spacing: 8) {
                HStack(spacing: 4) {
                    ForEach(0..<3) { index in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(index == 0 ? Color.orange : Color.gray.opacity(0.3))
                            .frame(width: 25, height: 8)
                            .scaleEffect(x: index == 0 ? budgetProgress : 1, y: 1, anchor: .leading)
                    }
                }
                
                Text("Budget")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .offset(y: 90)
            
            // 4. Credit Card (Left Top)
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.purple, Color.pink]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 50, height: 35)
                .overlay(
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Circle()
                                .fill(Color.white.opacity(0.3))
                                .frame(width: 8, height: 8)
                            Circle()
                                .fill(Color.white.opacity(0.3))
                                .frame(width: 8, height: 8)
                        }
                        Rectangle()
                            .fill(Color.white.opacity(0.3))
                            .frame(height: 2)
                    }
                    .padding(4)
                )
                .rotation3DEffect(
                    .degrees(creditCardFlip),
                    axis: (x: 0, y: 1, z: 0)
                )
                .offset(x: -75, y: -45)
            
            // 5. Installment Indicator (Left Bottom)
            HStack(spacing: 3) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(index <= installmentStep ? Color.orange : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            .offset(x: -75, y: 45)
            
            // 6. Recurring Transaction (Right Top)
            ZStack {
                Circle()
                    .stroke(Color.cyan, lineWidth: 2)
                    .frame(width: 30, height: 30)
                    .scaleEffect(recurringPulse)
                    .opacity(2 - recurringPulse)
                
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.caption)
                    .foregroundColor(.cyan)
            }
            .offset(x: 75, y: -45)
            
            // Center Logo/Icon
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 60, height: 60)
                
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                    .rotationEffect(.degrees(sin(rotationAngle * .pi / 180) * 5))
            }
        }
        .onAppear {
            // Start all animations
            startAnimations()
        }
    }
    
    private func startAnimations() {
        // Continuous rotation
        withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
            rotationAngle = 360
        }
        
        // Transaction animation
        withAnimation(.spring(response: 0.6).delay(0.5)) {
            transactionScale = 1
        }
        
        // Transfer animation
        withAnimation(.easeInOut(duration: 1).delay(0.8).repeatForever(autoreverses: true)) {
            transferArrowOffset = 5
        }
        
        // Budget progress
        withAnimation(.easeInOut(duration: 1.5).delay(1).repeatForever(autoreverses: false)) {
            budgetProgress = 1
        }
        
        // Credit card flip
        withAnimation(.easeInOut(duration: 2).delay(0.3).repeatForever(autoreverses: true)) {
            creditCardFlip = 180
        }
        
        // Installment steps
        Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { _ in
            withAnimation {
                installmentStep = (installmentStep + 1) % 3
            }
        }
        
        // Recurring pulse
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
            recurringPulse = 1.5
        }
    }
}

// MARK: - Enhanced Feature Pages

// 1. All-in-One Financial Hub
struct AllInOneFeaturePage: View {
    @State private var animateCards = false
    @State private var selectedCard = 1
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(spacing: 30) { // spacing eski haline döndü
            // Animated Cards Stack
            ZStack {
                // Kredi Kartı
                RoundedRectangle(cornerRadius: 20)
                    .fill(LinearGradient(
                        gradient: Gradient(colors: [Color.purple, Color.pink]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 140, height: 90)
                    .overlay(
                        VStack(alignment: .leading) {
                            HStack {
                                Image(systemName: "creditcard.fill")
                                    .font(.title3)
                                Spacer()
                            }
                            Spacer()
                            Text("•••• 4567")
                                .font(.caption)
                        }
                        .foregroundColor(.white)
                        .padding(12)
                    )
                    .rotation3DEffect(
                        .degrees(animateCards ? (selectedCard == 0 ? 0 : -20) : 0),
                        axis: (x: 0, y: 1, z: 0)
                    )
                    .offset(x: animateCards ? (selectedCard == 0 ? 0 : -60) : 0)
                    .scaleEffect(animateCards ? (selectedCard == 0 ? 1 : 0.9) : 0.8)
                    .opacity(animateCards ? 1 : 0)
                    .onTapGesture { withAnimation(.spring()) { selectedCard = 0 } }
                
                // Cüzdan
                RoundedRectangle(cornerRadius: 20)
                    .fill(LinearGradient(
                        gradient: Gradient(colors: [Color.blue, Color.cyan]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 140, height: 90)
                    .overlay(
                        VStack(alignment: .leading) {
                            HStack {
                                Image(systemName: "wallet.pass.fill")
                                    .font(.title3)
                                Spacer()
                            }
                            Spacer()
                            Text("₺12,450")
                                .font(.caption)
                                .bold()
                        }
                        .foregroundColor(.white)
                        .padding(12)
                    )
                    .scaleEffect(animateCards ? (selectedCard == 1 ? 1.1 : 0.9) : 0.8)
                    .opacity(animateCards ? 1 : 0)
                    .zIndex(selectedCard == 1 ? 1 : 0)
                    .onTapGesture { withAnimation(.spring()) { selectedCard = 1 } }
                
                // Kredi
                RoundedRectangle(cornerRadius: 20)
                    .fill(LinearGradient(
                        gradient: Gradient(colors: [Color.orange, Color.red]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 140, height: 90)
                    .overlay(
                        VStack(alignment: .leading) {
                            HStack {
                                Image(systemName: "banknote.fill")
                                    .font(.title3)
                                Spacer()
                            }
                            Spacer()
                            Text("12/36")
                                .font(.caption)
                        }
                        .foregroundColor(.white)
                        .padding(12)
                    )
                    .rotation3DEffect(
                        .degrees(animateCards ? (selectedCard == 2 ? 0 : 20) : 0),
                        axis: (x: 0, y: 1, z: 0)
                    )
                    .offset(x: animateCards ? (selectedCard == 2 ? 0 : 60) : 0)
                    .scaleEffect(animateCards ? (selectedCard == 2 ? 1 : 0.9) : 0.8)
                    .opacity(animateCards ? 1 : 0)
                    .onTapGesture { withAnimation(.spring()) { selectedCard = 2 } }
            }
            .frame(height: 150)
            .padding(.top, -50) // Sadece görsel yukarıda
            .padding(.bottom, 20) // <-- BU SATIRI EKLEYİN
            
            VStack(spacing: 20) {
                Text(LocalizedStringKey("onboarding.allinone.title"))
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text(LocalizedStringKey("onboarding.allinone.description"))
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .offset(y: animateCards ? 0 : 20)
            .opacity(animateCards ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                animateCards = true
            }
            // Auto-rotate cards
            Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { _ in
                withAnimation(.spring()) {
                    selectedCard = (selectedCard + 1) % 3
                }
            }
        }
    }
}

// 2. Smart Budget Management
struct SmartBudgetFeaturePage: View {
    @State private var animateProgress = false
    @State private var rolloverAmount: Double = 0
    
    var body: some View {
        VStack(spacing: 30) { // spacing eski haline döndü
            // Animated Budget Visual
            ZStack {
                // Main Budget Circle
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 20)
                    .frame(width: 120, height: 120)
                
                Circle()
                    .trim(from: 0, to: animateProgress ? 0.75 : 0)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.green, Color.yellow]),
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 20, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                
                VStack(spacing: 4) {
                    Text("75%")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text(LocalizedStringKey("onboarding.budget.used"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .opacity(animateProgress ? 1 : 0)
                
                // Rollover Animation
                if rolloverAmount > 0 {
                    Text("+₺\(Int(rolloverAmount))")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(20)
                        .offset(x: 60, y: -60)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(height: 150)
            .padding(.top, -50) // Sadece görsel yukarıda
            .padding(.bottom, 20) // <-- BU SATIRI EKLEYİN
            
            VStack(spacing: 20) {
                Text(LocalizedStringKey("onboarding.budget.title"))
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text(LocalizedStringKey("onboarding.budget.description"))
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .offset(y: animateProgress ? 0 : 20)
            .opacity(animateProgress ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) {
                animateProgress = true
            }
            // Rollover animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.spring()) {
                    rolloverAmount = 150
                }
            }
        }
    }
}

// 3. Insightful Reports
struct InsightfulReportsFeaturePage: View {
    @State private var animateCharts = false
    @State private var chartValues: [Double] = [0, 0, 0, 0, 0]
    let targetValues: [Double] = [0.6, 0.8, 0.4, 0.9, 0.7]
    
    var body: some View {
        VStack(spacing: 30) { // spacing eski haline döndü
            // Animated Bar Chart
            VStack(spacing: 15) {
                HStack(alignment: .bottom, spacing: 12) {
                    ForEach(0..<5) { index in
                        VStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color.blue.opacity(0.8),
                                            Color.purple.opacity(0.8)
                                        ]),
                                        startPoint: .bottom,
                                        endPoint: .top
                                    )
                                )
                                .frame(width: 30, height: CGFloat(chartValues[index] * 100))
                            
                            Text(["M", "T", "W", "T", "F"][index])
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .opacity(animateCharts ? 1 : 0)
                
                // Pie Chart Icon
                if animateCharts {
                    HStack(spacing: 20) {
                        // Mini pie chart representation
                        ZStack {
                            Circle()
                                .stroke(Color.orange, lineWidth: 15)
                                .frame(width: 40, height: 40)
                                .opacity(0.3)
                            
                            Circle()
                                .trim(from: 0, to: 0.3)
                                .stroke(Color.orange, lineWidth: 15)
                                .frame(width: 40, height: 40)
                                .rotationEffect(.degrees(-90))
                            
                            Circle()
                                .trim(from: 0.3, to: 0.6)
                                .stroke(Color.green, lineWidth: 15)
                                .frame(width: 40, height: 40)
                                .rotationEffect(.degrees(-90))
                            
                            Circle()
                                .trim(from: 0.6, to: 1)
                                .stroke(Color.blue, lineWidth: 15)
                                .frame(width: 40, height: 40)
                                .rotationEffect(.degrees(-90))
                        }
                        .scaleEffect(animateCharts ? 1 : 0)
                        
                        // Heat map representation
                        VStack(spacing: 4) {
                            HStack(spacing: 4) {
                                ForEach(0..<3) { _ in
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.red.opacity(Double.random(in: 0.2...0.9)))
                                        .frame(width: 15, height: 15)
                                }
                            }
                            HStack(spacing: 4) {
                                ForEach(0..<3) { _ in
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.orange.opacity(Double.random(in: 0.2...0.9)))
                                        .frame(width: 15, height: 15)
                                }
                            }
                        }
                        .scaleEffect(animateCharts ? 1 : 0)
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(height: 180)
            .padding(.top, -50) // Sadece görsel yukarıda
            .padding(.bottom, 20) // <-- BU SATIRI EKLEYİN
            
            VStack(spacing: 20) {
                Text(LocalizedStringKey("onboarding.reports.title"))
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text(LocalizedStringKey("onboarding.reports.description"))
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .offset(y: animateCharts ? 0 : 20)
            .opacity(animateCharts ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) {
                animateCharts = true
                // Animate bars
                for i in 0..<5 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.1) {
                        withAnimation(.spring()) {
                            chartValues[i] = targetValues[i]
                        }
                    }
                }
            }
        }
    }
}

// 4. Limitless Categorization
struct IntelligentCategorizationFeaturePage: View {
    @State private var animateCategories = false
    @State private var categoryPositions: [CGSize] = Array(repeating: .zero, count: 8)
    @State private var categoryOpacities: [Double] = Array(repeating: 0, count: 8)
    
    // Örnek kategoriler - farklı renkler ve ikonlar
    let sampleCategories = [
        (icon: "gamecontroller.fill", color: Color.purple, name: "Gaming"),
        (icon: "pawprint.fill", color: Color.brown, name: "Pets"),
        (icon: "book.fill", color: Color.blue, name: "Education"),
        (icon: "dumbbell.fill", color: Color.orange, name: "Fitness"),
        (icon: "airplane", color: Color.cyan, name: "Travel"),
        (icon: "heart.fill", color: Color.pink, name: "Charity"),
        (icon: "wrench.and.screwdriver.fill", color: Color.gray, name: "Maintenance"),
        (icon: "leaf.fill", color: Color.green, name: "Garden")
    ]
    
    var body: some View {
        VStack(spacing: 30) { // spacing eski haline döndü
            // Animated Categories Grid
            ZStack {
                ForEach(0..<sampleCategories.count, id: \.self) { index in
                    CategoryBubble(
                        icon: sampleCategories[index].icon,
                        color: sampleCategories[index].color,
                        name: sampleCategories[index].name
                    )
                    .offset(categoryPositions[index])
                    .opacity(categoryOpacities[index])
                    .scaleEffect(categoryOpacities[index])
                    .zIndex(Double(index % 2)) // Layering effect
                }
                
                // Center plus button
                if animateCategories {
                    ZStack {
                        Circle()
                            .fill(Color.accentColor.opacity(0.1))
                            .frame(width: 60, height: 60)
                        
                        Image(systemName: "plus")
                            .font(.title2)
                            .foregroundColor(.accentColor)
                    }
                    .scaleEffect(animateCategories ? 1 : 0)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(height: 200)
            .padding(.top, -50) // Sadece görsel yukarıda
            .padding(.bottom, 20) // <-- BU SATIRI EKLEYİN
            
            VStack(spacing: 20) {
                Text(LocalizedStringKey("onboarding.ai.title"))
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text(LocalizedStringKey("onboarding.ai.description"))
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .offset(y: animateCategories ? 0 : 20)
            .opacity(animateCategories ? 1 : 0)
        }
        .onAppear {
            // Set initial positions (off-screen)
            categoryPositions[0] = CGSize(width: -150, height: -60)  // Top left
            categoryPositions[1] = CGSize(width: 150, height: -60)   // Top right
            categoryPositions[2] = CGSize(width: -180, height: 0)    // Left
            categoryPositions[3] = CGSize(width: 180, height: 0)     // Right
            categoryPositions[4] = CGSize(width: -150, height: 60)   // Bottom left
            categoryPositions[5] = CGSize(width: 150, height: 60)    // Bottom right
            categoryPositions[6] = CGSize(width: -90, height: -90)   // Extra positions
            categoryPositions[7] = CGSize(width: 90, height: 90)     // Extra positions
            
            // Animate text
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                animateCategories = true
            }
            
            // Animate categories one by one with staggered timing
            for i in 0..<sampleCategories.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.15 + 0.3) {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                        // Move to final positions
                        switch i {
                        case 0: categoryPositions[i] = CGSize(width: -70, height: -50)
                        case 1: categoryPositions[i] = CGSize(width: 70, height: -50)
                        case 2: categoryPositions[i] = CGSize(width: -90, height: 10)
                        case 3: categoryPositions[i] = CGSize(width: 90, height: 10)
                        case 4: categoryPositions[i] = CGSize(width: -70, height: 70)
                        case 5: categoryPositions[i] = CGSize(width: 70, height: 70)
                        case 6: categoryPositions[i] = CGSize(width: 0, height: -80)
                        case 7: categoryPositions[i] = CGSize(width: 0, height: 100)
                        default: break
                        }
                        categoryOpacities[i] = 1
                    }
                }
            }
            
            // Gentle floating animation
            Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { _ in
                for i in 0..<sampleCategories.count {
                    withAnimation(.easeInOut(duration: 2).delay(Double(i) * 0.1)) {
                        let randomX = CGFloat.random(in: -5...5)
                        let randomY = CGFloat.random(in: -5...5)
                        categoryPositions[i].width += randomX
                        categoryPositions[i].height += randomY
                    }
                }
            }
        }
    }
}

// Category Bubble Component
struct CategoryBubble: View {
    let icon: String
    let color: Color
    let name: String
    
    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 50, height: 50)
                
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
            }
            
            Text(name)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(width: 70)
    }
}

// 5. Secure Backup
struct SecureBackupFeaturePage: View {
    @State private var animateCloud = false
    @State private var syncProgress: Double = 0
    @State private var devicePositions: [(offset: CGSize, opacity: Double)] = [
        (CGSize(width: -80, height: 60), 0),
        (CGSize(width: 80, height: 60), 0)
    ]
    
    var body: some View {
        VStack(spacing: 30) { // spacing eski haline döndü
            // Cloud Sync Animation
            ZStack {
                // Cloud
                Image(systemName: "icloud.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.blue.opacity(0.8))
                    .scaleEffect(animateCloud ? 1 : 0.8)
                    .opacity(animateCloud ? 1 : 0)
                
                // Sync progress
                if syncProgress > 0 {
                    Circle()
                        .trim(from: 0, to: syncProgress)
                        .stroke(Color.green, lineWidth: 3)
                        .frame(width: 90, height: 90)
                        .rotationEffect(.degrees(-90))
                }
                
                // Devices
                Image(systemName: "iphone")
                    .font(.title)
                    .foregroundColor(.gray)
                    .offset(devicePositions[0].offset)
                    .opacity(devicePositions[0].opacity)
                
                Image(systemName: "ipad")
                    .font(.title)
                    .foregroundColor(.gray)
                    .offset(devicePositions[1].offset)
                    .opacity(devicePositions[1].opacity)
                
                // Check mark
                if syncProgress >= 1 {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title)
                        .foregroundColor(.green)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(height: 150)
            .padding(.top, -50) // Sadece görsel yukarıda
            .padding(.bottom, 20) // <-- BU SATIRI EKLEYİN
            
            VStack(spacing: 20) {
                Text(LocalizedStringKey("onboarding.backup.title"))
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text(LocalizedStringKey("onboarding.backup.description"))
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .offset(y: animateCloud ? 0 : 20)
            .opacity(animateCloud ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) {
                animateCloud = true
            }
            
            // Animate devices
            for i in 0..<devicePositions.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.3 + 0.5) {
                    withAnimation(.spring()) {
                        devicePositions[i].opacity = 1
                    }
                }
            }
            
            // Animate sync progress
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                withAnimation(.linear(duration: 1.5)) {
                    syncProgress = 1
                }
            }
        }
    }
}

// MARK: - Feature Page (Old implementation - removing)
struct FeaturePage: View {
    let icon: String
    let title: LocalizedStringKey
    let description: LocalizedStringKey
    let color: Color
    
    @State private var animateIcon = false
    @State private var animateText = false
    
    var body: some View {
        VStack(spacing: 40) {
            // Animated icon
            ZStack {
                Circle()
                    .fill(color.opacity(0.1))
                    .frame(width: 120, height: 120)
                    .scaleEffect(animateIcon ? 1 : 0.8)
                
                Image(systemName: icon)
                    .font(.system(size: 50))
                    .foregroundColor(color)
                    .rotationEffect(.degrees(animateIcon ? 0 : -10))
            }
            .opacity(animateIcon ? 1 : 0)
            
            VStack(spacing: 20) {
                Text(title)
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text(description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .offset(y: animateText ? 0 : 30)
            .opacity(animateText ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                animateIcon = true
            }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2)) {
                animateText = true
            }
        }
    }
}

// MARK: - Personalization with Sign In Page
struct PersonalizationPage: View {
    @Binding var selectedLanguage: String
    @Binding var selectedCurrency: String
    let onComplete: () -> Void
    
    @EnvironmentObject var appSettings: AppSettings
    @State private var animateContent = false
    @Environment(\.colorScheme) private var colorScheme
    
    // Currency arama için
    @State private var showCurrencySearch = false
    
    // Desteklenen diller listesi
    let supportedLanguages = [
        ("tr", "🇹🇷", "Türkçe"),
        ("en", "🇬🇧", "English"),
        ("de", "🇩🇪", "Deutsch"),
        ("fr", "🇫🇷", "Français"),
        ("es", "🇪🇸", "Español"),
        ("it", "🇮🇹", "Italiano"),
        ("ja", "🇯🇵", "日本語"),
        ("zh", "🇨🇳", "中文"),
        ("id", "🇮🇩", "Bahasa Indonesia"),
        ("hi", "🇮🇳", "हिन्दी"),
        ("vi", "🇻🇳", "Tiếng Việt"),
        ("th", "🇹🇭", "ไทย"),
        ("ms", "🇲🇾", "Bahasa Melayu")
    ]
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Kaydırılabilir içerik
                ScrollView {
                    VStack(spacing: 40) {
                        Text(LocalizedStringKey("onboarding.personalize.title"))
                            .font(.title)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                            .offset(y: animateContent ? 0 : -20)
                            .opacity(animateContent ? 1 : 0)
                            .padding(.top, 10)
                        
                        VStack(spacing: 30) {
                            // Dil seçimi - DROPDOWN
                            VStack(alignment: .leading, spacing: 15) {
                                Text(LocalizedStringKey("onboarding.select_language"))
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                
                                Menu {
                                    ForEach(supportedLanguages, id: \.0) { lang in
                                        Button(action: {
                                            withAnimation(.spring()) {
                                                selectedLanguage = lang.0
                                            }
                                        }) {
                                            HStack {
                                                Text("\(lang.1) \(lang.2)")
                                                if selectedLanguage == lang.0 {
                                                    Spacer()
                                                    Image(systemName: "checkmark")
                                                }
                                            }
                                        }
                                    }
                                } label: {
                                    HStack {
                                        if let selected = supportedLanguages.first(where: { $0.0 == selectedLanguage }) {
                                            Text("\(selected.1)")
                                                .font(.title2)
                                            Text(selected.2)
                                                .font(.body)
                                                .foregroundColor(.primary)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.down")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color(.systemGray6))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
                                    )
                                }
                            }
                            
                            // Para birimi seçimi - ARAMA ÖZELLİKLİ
                            VStack(alignment: .leading, spacing: 15) {
                                Text(LocalizedStringKey("onboarding.select_currency"))
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                
                                Button(action: {
                                    showCurrencySearch = true
                                }) {
                                    HStack {
                                        if let currency = Currency(rawValue: selectedCurrency) {
                                            Text(currency.symbol)
                                                .font(.title2)
                                                .frame(width: 30)
                                            
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(currency.rawValue)
                                                    .font(.body)
                                                    .fontWeight(.medium)
                                                Text(LocalizedStringKey(currency.localizedNameKey))
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        
                                        Spacer()
                                        
                                        Image(systemName: "magnifyingglass")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color(.systemGray6))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
                                    )
                                }
                                .foregroundColor(.primary)
                            }
                        }
                        .padding(.horizontal, 30)
                        .padding(.bottom, 220) // Sign in button ve linkler için boşluk
                    }
                }
                .scaleEffect(animateContent ? 1 : 0.9)
                .opacity(animateContent ? 1 : 0)
                .mask(
                    LinearGradient(
                        gradient: Gradient(
                            colors: [.black, .black, .black, .clear]
                        ),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                
                // Sabit alt bölüm - Başla Butonu
                VStack(spacing: 12) {
                    Button(action: {
                        // Seçilen ayarları uygula
                        appSettings.languageCode = selectedLanguage
                        appSettings.currencyCode = selectedCurrency
                        
                        // İlk verileri oluştur
                        onComplete()
                        
                        // Ana ekrana geç
                        withAnimation(.easeInOut(duration: 0.5)) {
                            appSettings.hasCompletedOnboarding = true
                        }
                    }) {
                        Text(LocalizedStringKey("onboarding.start_button"))
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .cornerRadius(16)
                            .shadow(radius: 5)
                    }
                    .padding(.horizontal, 30)
                    
                    // Privacy Notice with Links
                    VStack(spacing: 8) {
                        Text(LocalizedStringKey("onboarding.privacy_notice"))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        
                        // Terms and Privacy Links
                        HStack(spacing: 15) {
                            Link(destination: URL(string: "https://walleo.app/#privacy")!) {
                                HStack(spacing: 4) {
                                    Image(systemName: "lock.shield")
                                        .font(.caption2)
                                    Text(LocalizedStringKey("onboarding.privacy_policy"))
                                        .font(.caption2)
                                        .underline()
                                }
                            }
                            .foregroundColor(.accentColor)
                            
                            Text("•")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            Link(destination: URL(string: "https://walleo.app/#terms")!) {
                                HStack(spacing: 4) {
                                    Image(systemName: "doc.text")
                                        .font(.caption2)
                                    Text(LocalizedStringKey("onboarding.terms_of_use"))
                                        .font(.caption2)
                                        .underline()
                                }
                            }
                            .foregroundColor(.accentColor)
                        }
                    }
                }
                .padding(.top, 15)
                .padding(.bottom, 10)
            }
        }
        .sheet(isPresented: $showCurrencySearch) {
            CurrencySearchView(
                selectedCurrency: $selectedCurrency,
                isPresented: $showCurrencySearch
            )
            .environmentObject(appSettings)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                animateContent = true
            }
        }
    }
}

// Para birimi arama view'ı - GÜZEL VE TEMİZ
struct CurrencySearchView: View {
    @Binding var selectedCurrency: String
    @Binding var isPresented: Bool
    @EnvironmentObject var appSettings: AppSettings
    
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool
    
    var filteredCurrencies: [Currency] {
        if searchText.isEmpty {
            return Currency.allCases
        } else {
            return Currency.allCases.filter { currency in
                // ISO kodunda ara
                currency.rawValue.localizedCaseInsensitiveContains(searchText) ||
                // Sembolde ara
                currency.symbol.localizedCaseInsensitiveContains(searchText) ||
                // Lokalize edilmiş isimde ara (basit yaklaşım)
                NSLocalizedString(currency.localizedNameKey, comment: "")
                    .localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Arama alanı
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField(LocalizedStringKey("search.currency"), text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .focused($isSearchFocused)
                    
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                                .font(.system(size: 16))
                        }
                    }
                }
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding()
                
                // Para birimi listesi
                List {
                    ForEach(filteredCurrencies, id: \.self) { currency in
                        Button(action: {
                            withAnimation(.spring()) {
                                selectedCurrency = currency.rawValue
                            }
                            isPresented = false
                        }) {
                            HStack(spacing: 16) {
                                Text(currency.symbol)
                                    .font(.title2)
                                    .fontWeight(.medium)
                                    .frame(width: 40)
                                    .foregroundColor(currency.rawValue == selectedCurrency ? .white : .primary)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(currency.rawValue)
                                        .font(.headline)
                                        .foregroundColor(currency.rawValue == selectedCurrency ? .white : .primary)
                                    Text(LocalizedStringKey(currency.localizedNameKey))
                                        .font(.caption)
                                        .foregroundColor(currency.rawValue == selectedCurrency ? .white.opacity(0.8) : .secondary)
                                }
                                
                                Spacer()
                                
                                if selectedCurrency == currency.rawValue {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.white)
                                        .font(.title3)
                                }
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(currency.rawValue == selectedCurrency ? Color.accentColor : Color.clear)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 2, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                }
                .listStyle(PlainListStyle())
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(LocalizedStringKey("onboarding.select_currency"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(LocalizedStringKey("common.done")) {
                        isPresented = false
                    }
                    .fontWeight(.medium)
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isSearchFocused = true
            }
        }
    }
}

// MARK: - Language Option
struct LanguageOption: View {
    let flag: String
    let name: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(flag)
                    .font(.title)
                
                Text(name)
                    .font(.headline)
                    .foregroundColor(isSelected ? .primary : .secondary)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .transition(.scale)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.gray.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Currency Option
struct CurrencyOption: View {
    let currency: Currency
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(currency.symbol)
                    .font(.title)
                
                Text(currency.rawValue)
                    .font(.headline)
                    .foregroundColor(isSelected ? .primary : .secondary)
                
                Text(LocalizedStringKey(currency.localizedNameKey))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.gray.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Page Indicator
struct PageIndicator: View {
    let currentPage: Int
    let totalPages: Int
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalPages, id: \.self) { index in
                Circle()
                    .fill(currentPage == index ? Color.accentColor : Color.gray.opacity(0.3))
                    .frame(width: 8, height: 8)
                    .scaleEffect(currentPage == index ? 1.2 : 1)
                    .animation(.spring(), value: currentPage)
            }
        }
    }
}
