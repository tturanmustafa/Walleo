import SwiftUI
import AuthenticationServices
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
    @State private var isSigningIn = false
    
    // Animasyon state'leri
    @State private var logoScale: CGFloat = 0.8
    @State private var contentOpacity: Double = 0
    
    // Sayfa sayıları
    let welcomeAndFeaturePages = 4 // Welcome + 3 özellik
    let personalizationPage = 4
    let totalPages = 5
    
    init() {
        let preferredLanguage = Locale.preferredLanguages.first ?? "en"
        let languageCode = String(preferredLanguage.prefix(2))
        
        // Desteklenen diller listesi
        let supportedLanguages = ["tr", "en", "de", "fr", "es", "it", "ja", "zh", "id", "hi", "vi", "th", "ms"]
        
        if supportedLanguages.contains(languageCode) {
            _selectedLanguage = State(initialValue: languageCode)
        } else {
            _selectedLanguage = State(initialValue: "en")
        }
        
        // Para birimi seçimi
        switch languageCode {
        case "tr": _selectedCurrency = State(initialValue: "TRY")
        case "de": _selectedCurrency = State(initialValue: "EUR")
        case "fr": _selectedCurrency = State(initialValue: "EUR")
        case "es": _selectedCurrency = State(initialValue: "EUR")
        case "it": _selectedCurrency = State(initialValue: "EUR")
        case "ja": _selectedCurrency = State(initialValue: "JPY")
        case "zh": _selectedCurrency = State(initialValue: "CNY")
        case "id": _selectedCurrency = State(initialValue: "IDR")
        case "hi": _selectedCurrency = State(initialValue: "INR")
        case "vi": _selectedCurrency = State(initialValue: "VND")
        case "th": _selectedCurrency = State(initialValue: "THB")
        case "ms": _selectedCurrency = State(initialValue: "MYR")
        default: _selectedCurrency = State(initialValue: "USD")
        }
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
            VStack(spacing: 0) {
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
                    .frame(width: 80, height: 80)
                    .scaleEffect(logoScale)
                    .padding(.top, 10)
                
                Spacer()
                
                // İçerik alanı
                TabView(selection: $currentPage) {
                    WelcomePage()
                        .tag(0)
                    
                    FeaturePage(
                        icon: "chart.line.uptrend.xyaxis",
                        title: LocalizedStringKey("onboarding.feature1.title"),
                        description: LocalizedStringKey("onboarding.feature1.description"),
                        color: .blue
                    )
                    .tag(1)
                    
                    FeaturePage(
                        icon: "chart.pie.fill",
                        title: LocalizedStringKey("onboarding.feature2.title"),
                        description: LocalizedStringKey("onboarding.feature2.description"),
                        color: .green
                    )
                    .tag(2)
                    
                    FeaturePage(
                        icon: "bell.badge.fill",
                        title: LocalizedStringKey("onboarding.feature3.title"),
                        description: LocalizedStringKey("onboarding.feature3.description"),
                        color: .orange
                    )
                    .tag(3)
                    
                    PersonalizationWithSignInPage(
                        selectedLanguage: $selectedLanguage,
                        selectedCurrency: $selectedCurrency,
                        isSigningIn: $isSigningIn,
                        handleSignIn: handleSignIn
                    )
                    .tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .opacity(contentOpacity)
                
                Spacer()
                
                // Alt kontroller
                VStack(spacing: 20) {
                    // Page indicator
                    if currentPage < totalPages - 1 {
                        PageIndicator(currentPage: currentPage, totalPages: totalPages)
                            .padding(.bottom, 10)
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
    
    private func handleSignIn(result: Result<ASAuthorization, Error>) {
        isSigningIn = true
        
        switch result {
        case .success(let authorization):
            if let _ = authorization.credential as? ASAuthorizationAppleIDCredential {
                // Seçilen ayarları uygula
                appSettings.languageCode = selectedLanguage
                appSettings.currencyCode = selectedCurrency
                
                // İlk verileri oluştur
                seedInitialData()
                
                // Ana ekrana geç
                withAnimation(.easeInOut(duration: 0.5)) {
                    appSettings.hasCompletedOnboarding = true
                }
            }
        case .failure(let error):
            isSigningIn = false
            Logger.log("Sign in with Apple failed: \(error.localizedDescription)", log: Logger.service, type: .error)
        }
    }
    
    private func seedInitialData() {
        // Mevcut seedInitialData fonksiyonu aynı kalacak
        do {
            let descriptor = FetchDescriptor<AppMetadata>()
            if let metadata = try modelContext.fetch(descriptor).first, metadata.defaultCategoriesAdded {
                return
            }
            
            let categoryDescriptor = FetchDescriptor<Kategori>()
            let existingCategoriesCount = try modelContext.fetchCount(categoryDescriptor)
            
            if existingCategoriesCount == 0 {
                // Kategorileri ekle (önceki kod aynı)
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
            
        } catch {
            Logger.log("Initial data setup error: \(error.localizedDescription)", log: Logger.data, type: .fault)
        }
    }
}

// MARK: - Welcome Page
struct WelcomePage: View {
    @State private var animateElements = false
    
    var body: some View {
        VStack(spacing: 30) {
            Image("text_logo_onboarding")
                .resizable()
                .scaledToFit()
                .frame(height: 60)
                .scaleEffect(animateElements ? 1 : 0.8)
                .opacity(animateElements ? 1 : 0)
            
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

// MARK: - Feature Page
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
struct PersonalizationWithSignInPage: View {
    @Binding var selectedLanguage: String
    @Binding var selectedCurrency: String
    @Binding var isSigningIn: Bool
    let handleSignIn: (Result<ASAuthorization, Error>) -> Void
    
    @State private var animateContent = false
    @Environment(\.colorScheme) private var colorScheme
    
    // Desteklenen diller - uygulamadaki ayarlardan
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
                            // Dil seçimi
                            VStack(alignment: .leading, spacing: 15) {
                                Text(LocalizedStringKey("onboarding.select_language"))
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                
                                VStack(spacing: 12) {
                                    ForEach(supportedLanguages, id: \.0) { lang in
                                        LanguageOption(
                                            flag: lang.1,
                                            name: lang.2,
                                            isSelected: selectedLanguage == lang.0
                                        ) {
                                            withAnimation(.spring()) {
                                                selectedLanguage = lang.0
                                            }
                                        }
                                    }
                                }
                            }
                            
                            // Para birimi seçimi
                            VStack(alignment: .leading, spacing: 15) {
                                Text(LocalizedStringKey("onboarding.select_currency"))
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                
                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                    ForEach(Currency.allCases) { currency in
                                        CurrencyOption(
                                            currency: currency,
                                            isSelected: selectedCurrency == currency.rawValue
                                        ) {
                                            withAnimation(.spring()) {
                                                selectedCurrency = currency.rawValue
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 30)
                        .padding(.bottom, 200) // Sign in button için boşluk
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
                
                // Sabit Sign in with Apple bölümü
                VStack(spacing: 15) {
                    if isSigningIn {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(1.5)
                            .padding()
                    } else {
                        SignInWithAppleButton(
                            .signIn,
                            onRequest: { request in
                                request.requestedScopes = [.fullName, .email]
                            },
                            onCompletion: handleSignIn
                        )
                        .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                        .frame(height: 55)
                        .cornerRadius(16)
                        .shadow(radius: 5)
                        .padding(.horizontal, 30)
                        
                        Text(LocalizedStringKey("onboarding.privacy_notice"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                }
                .padding(.top, 20)  // ← BU SATIRI EKLEYİN
                .padding(.bottom, 10)            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                animateContent = true
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
