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
    
    // Sayfa sayıları güncellendi
    let welcomeAndFeaturePages = 6 // Welcome + 5 özellik
    let personalizationPage = 6
    let totalPages = 7
    
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
                    .frame(width: 160, height: 160)
                    .scaleEffect(logoScale)
                    .padding(.top, 10)
                
                Spacer()
                
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
                    
                    PersonalizationWithSignInPage(
                        selectedLanguage: $selectedLanguage,
                        selectedCurrency: $selectedCurrency,
                        isSigningIn: $isSigningIn,
                        handleSignIn: handleSignIn
                    )
                    .tag(6)
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

// MARK: - Enhanced Feature Pages

// 1. All-in-One Financial Hub
struct AllInOneFeaturePage: View {
    @State private var animateCards = false
    @State private var selectedCard = 1
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(spacing: 30) {
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
            .offset(y: animateCards ? 0 : 30)
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
        VStack(spacing: 30) {
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
            .offset(y: animateProgress ? 0 : 30)
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
        VStack(spacing: 30) {
            // Animated Bar Chart
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
            .frame(height: 150)
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
            .offset(y: animateCharts ? 0 : 30)
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
        VStack(spacing: 30) {
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
            .offset(y: animateCategories ? 0 : 30)
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
        VStack(spacing: 30) {
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
            .offset(y: animateCloud ? 0 : 30)
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
                .padding(.top, 20)
                .padding(.bottom, 10)
            }
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
