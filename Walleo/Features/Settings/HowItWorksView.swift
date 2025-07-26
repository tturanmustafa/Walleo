import SwiftUI

// MARK: - Ana View
struct HowItWorksView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedCategory: FeatureCategory = .quickStart
    @State private var expandedCards: Set<String> = []
    @State private var animateContent = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Gradient Background
                backgroundGradient
                
                VStack(spacing: 0) {
                    // Category Selector
                    categorySelector
                        .padding(.top, 10)
                    
                    // Content
                    ScrollView {
                        VStack(spacing: 16) {
                            ForEach(featuresForCategory(selectedCategory), id: \.id) { feature in
                                FeatureCardView(
                                    feature: feature,
                                    isExpanded: expandedCards.contains(feature.id)
                                ) {
                                    toggleCard(feature.id)
                                }
                                .transition(.asymmetric(
                                    insertion: .scale.combined(with: .opacity),
                                    removal: .scale.combined(with: .opacity)
                                ))
                            }
                        }
                        .padding()
                        .padding(.bottom, 50)
                    }
                    .animation(.spring(), value: selectedCategory)
                }
            }
            .navigationTitle(LocalizedStringKey("how_it_works.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(LocalizedStringKey("common.done")) {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                animateContent = true
            }
        }
    }
    
    // MARK: - Background Gradient
    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(hex: colorScheme == .dark ? "1C1C1E" : "F2F2F7"),
                Color(hex: colorScheme == .dark ? "000000" : "FFFFFF")
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
    
    // MARK: - Category Selector
    private var categorySelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(FeatureCategory.allCases, id: \.self) { category in
                    CategoryButton(
                        category: category,
                        isSelected: selectedCategory == category
                    ) {
                        withAnimation(.spring()) {
                            selectedCategory = category
                            expandedCards.removeAll() // Reset expanded cards when switching
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Helper Functions
    private func toggleCard(_ id: String) {
        withAnimation(.spring()) {
            if expandedCards.contains(id) {
                expandedCards.remove(id)
            } else {
                expandedCards.insert(id)
            }
        }
    }
    
    private func featuresForCategory(_ category: FeatureCategory) -> [HowItWorksFeature] {
        switch category {
        case .quickStart:
            return quickStartFeatures
        case .accounts:
            return accountFeatures
        case .transactions:
            return transactionFeatures
        case .budgets:
            return budgetFeatures
        case .reports:
            return reportFeatures
        case .advanced:
            return advancedFeatures
        }
    }
}

// MARK: - Feature Category
enum FeatureCategory: String, CaseIterable {
    case quickStart = "how_it_works.category.quick_start"
    case accounts = "how_it_works.category.accounts"
    case transactions = "how_it_works.category.transactions"
    case budgets = "how_it_works.category.budgets"
    case reports = "how_it_works.category.reports"
    case advanced = "how_it_works.category.advanced"
    
    var icon: String {
        switch self {
        case .quickStart: return "sparkles"
        case .accounts: return "wallet.pass"
        case .transactions: return "plus.circle"
        case .budgets: return "chart.pie"
        case .reports: return "chart.bar"
        case .advanced: return "gearshape.2"
        }
    }
    
    var color: Color {
        switch self {
        case .quickStart: return .purple
        case .accounts: return .blue
        case .transactions: return .green
        case .budgets: return .orange
        case .reports: return .pink
        case .advanced: return .indigo
        }
    }
}

// MARK: - Category Button
struct CategoryButton: View {
    let category: FeatureCategory
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(isSelected ? category.color : Color.gray.opacity(0.2))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: category.icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(isSelected ? .white : .secondary)
                        .scaleEffect(isSelected ? 1.1 : 1)
                }
                
                Text(LocalizedStringKey(category.rawValue))
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(isSelected ? category.color : .secondary)
            }
            .scaleEffect(isSelected ? 1.05 : 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Feature Card View
struct FeatureCardView: View {
    let feature: HowItWorksFeature
    let isExpanded: Bool
    let onTap: () -> Void
    
    @State private var showAnimation = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Button(action: onTap) {
                HStack(spacing: 16) {
                    // Icon with animation
                    ZStack {
                        Circle()
                            .fill(feature.color.opacity(0.1))
                            .frame(width: 44, height: 44)
                        
                        Image(systemName: feature.icon)
                            .font(.system(size: 20))
                            .foregroundColor(feature.color)
                            .rotationEffect(.degrees(showAnimation ? 360 : 0))
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(LocalizedStringKey(feature.title))
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(LocalizedStringKey(feature.summary))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding()
            }
            .buttonStyle(PlainButtonStyle())
            
            // Expanded Content
            if isExpanded {
                VStack(alignment: .leading, spacing: 16) {
                    // Divider
                    Divider()
                        .padding(.horizontal)
                    
                    // Animated Illustration
                    feature.animationView
                        .frame(height: 120)
                        .padding(.horizontal)
                    
                    // Steps
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(feature.steps.enumerated()), id: \.offset) { index, step in
                            StepView(number: index + 1, text: step)
                                .transition(.asymmetric(
                                    insertion: .move(edge: .leading).combined(with: .opacity),
                                    removal: .opacity
                                ))
                        }
                    }
                    .padding(.horizontal)
                    
                    // Tips (if any)
                    if let tips = feature.tips, !tips.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Label(LocalizedStringKey("how_it_works.tips"), systemImage: "lightbulb.fill")
                                .font(.subheadline.bold())
                                .foregroundColor(.orange)
                            
                            ForEach(tips, id: \.self) { tip in
                                HStack(alignment: .top, spacing: 8) {
                                    Text("•")
                                        .foregroundColor(.orange)
                                    Text(LocalizedStringKey(tip))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                    
                    // Premium Badge (if needed)
                    if feature.isPremium {
                        HStack {
                            Image(systemName: "crown.fill")
                                .foregroundColor(.yellow)
                            Text(LocalizedStringKey("how_it_works.premium_feature"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                    }
                }
                .padding(.bottom, 8)
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: false)) {
                showAnimation = true
            }
        }
    }
}

// MARK: - Step View
struct StepView: View {
    let number: Int
    let text: String // LocalizedStringKey yerine String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 28, height: 28)
                
                Text("\(number)")
                    .font(.caption.bold())
                    .foregroundColor(.accentColor)
            }
            
            Text(LocalizedStringKey(text)) // String'i LocalizedStringKey'e çevir
                .font(.subheadline)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
        }
    }
}

// MARK: - Feature Model
struct HowItWorksFeature: Identifiable {
    let id = UUID().uuidString
    let title: String
    let summary: String
    let icon: String
    let color: Color
    let steps: [String] // LocalizedStringKey yerine String
    let tips: [String]?
    let isPremium: Bool
    let animationView: AnyView
    
    init(
        title: String,
        summary: String,
        icon: String,
        color: Color,
        steps: [String], // LocalizedStringKey yerine String
        tips: [String]? = nil,
        isPremium: Bool = false,
        animationView: AnyView = AnyView(EmptyView())
    ) {
        self.title = title
        self.summary = summary
        self.icon = icon
        self.color = color
        self.steps = steps
        self.tips = tips
        self.isPremium = isPremium
        self.animationView = animationView
    }
}

// MARK: - Animated Illustrations
struct AccountAnimationView: View {
    @State private var rotation: Double = 0
    @State private var scale: CGFloat = 1
    
    var body: some View {
        ZStack {
            // Basitleştirilmiş kart animasyonu
            ForEach(0..<3) { index in
                CardView(index: index, rotation: rotation, scale: scale)
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 10).repeatForever(autoreverses: false)) {
                rotation = 360
            }
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                scale = 1.1
            }
        }
    }
}

// Yardımcı View
struct CardView: View {
    let index: Int
    let rotation: Double
    let scale: CGFloat
    
    private let icons = ["wallet.pass", "creditcard", "banknote"]
    private let angle: Double
    
    init(index: Int, rotation: Double, scale: CGFloat) {
        self.index = index
        self.rotation = rotation
        self.scale = scale
        self.angle = Double(index) * 120
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.blue.opacity(0.6),
                        Color.purple.opacity(0.6)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 80, height: 50)
            .overlay(
                Image(systemName: icons[index])
                    .foregroundColor(.white)
            )
            .rotationEffect(.degrees(angle + rotation))
            .offset(
                x: cos((angle + rotation) * .pi / 180) * 40,
                y: sin((angle + rotation) * .pi / 180) * 40
            )
            .scaleEffect(scale)
    }
}

struct TransactionAnimationView: View {
    @State private var offset: CGFloat = -50
    @State private var opacity: Double = 0
    
    var body: some View {
        VStack(spacing: 20) {
            // Basitleştirilmiş para akışı animasyonu
            TransactionFlowRow(offset: offset, opacity: opacity)
            TransactionFlowRow(offset: offset + 20, opacity: max(0, opacity - 0.2))
            TransactionFlowRow(offset: offset + 40, opacity: max(0, opacity - 0.4))
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                offset = 50
                opacity = 1
            }
        }
    }
}

struct TransactionFlowRow: View {
    let offset: CGFloat
    let opacity: Double
    
    var body: some View {
        HStack {
            Image(systemName: "plus.circle.fill")
                .foregroundColor(.green)
                .font(.title2)
            
            Image(systemName: "arrow.right")
                .foregroundColor(.gray)
            
            Image(systemName: "minus.circle.fill")
                .foregroundColor(.red)
                .font(.title2)
        }
        .offset(y: offset)
        .opacity(opacity)
    }
}

struct BudgetAnimationView: View {
    @State private var progress: CGFloat = 0
    
    var body: some View {
        VStack(spacing: 10) {
            // Basitleştirilmiş pie chart animasyonu
            BudgetProgressCircle(progress: progress)
            
            // Progress text
            VStack(spacing: 2) {
                Text("\(Int(progress * 100))%")
                    .font(.headline)
                    .fontWeight(.bold)
                Text(LocalizedStringKey("how_it_works.used"))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                progress = 0.75
            }
        }
    }
}

struct BudgetProgressCircle: View {
    let progress: CGFloat
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 20)
                .frame(width: 80, height: 80)
            
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.green, Color.yellow, Color.red]),
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 20, lineCap: .round)
                )
                .frame(width: 80, height: 80)
                .rotationEffect(.degrees(-90))
        }
    }
}

// MARK: - Feature Data
let quickStartFeatures = [
    HowItWorksFeature(
        title: "how_it_works.quick_start.first_steps.title",
        summary: "how_it_works.quick_start.first_steps.summary",
        icon: "flag.checkered",
        color: .purple,
        steps: [
            "how_it_works.quick_start.first_steps.step1",
            "how_it_works.quick_start.first_steps.step2",
            "how_it_works.quick_start.first_steps.step3",
            "how_it_works.quick_start.first_steps.step4"
        ],
        tips: [
            "how_it_works.quick_start.first_steps.tip1",
            "how_it_works.quick_start.first_steps.tip2"
        ],
        animationView: AnyView(AccountAnimationView())
    ),
    HowItWorksFeature(
        title: "how_it_works.quick_start.navigation.title",
        summary: "how_it_works.quick_start.navigation.summary",
        icon: "map",
        color: .indigo,
        steps: [
            "how_it_works.quick_start.navigation.step1",
            "how_it_works.quick_start.navigation.step2",
            "how_it_works.quick_start.navigation.step3",
            "how_it_works.quick_start.navigation.step4"
        ]
    )
]

let accountFeatures = [
    HowItWorksFeature(
        title: "how_it_works.accounts.wallet.title",
        summary: "how_it_works.accounts.wallet.summary",
        icon: "wallet.pass",
        color: .blue,
        steps: [
            "how_it_works.accounts.wallet.step1",
            "how_it_works.accounts.wallet.step2",
            "how_it_works.accounts.wallet.step3"
        ],
        animationView: AnyView(AccountAnimationView())
    ),
    HowItWorksFeature(
        title: "how_it_works.accounts.credit_card.title",
        summary: "how_it_works.accounts.credit_card.summary",
        icon: "creditcard",
        color: .purple,
        steps: [
            "how_it_works.accounts.credit_card.step1",
            "how_it_works.accounts.credit_card.step2",
            "how_it_works.accounts.credit_card.step3",
            "how_it_works.accounts.credit_card.step4"
        ],
        tips: [
            "how_it_works.accounts.credit_card.tip1"
        ]
    ),
    HowItWorksFeature(
        title: "how_it_works.accounts.loan.title",
        summary: "how_it_works.accounts.loan.summary",
        icon: "banknote",
        color: .orange,
        steps: [
            "how_it_works.accounts.loan.step1",
            "how_it_works.accounts.loan.step2",
            "how_it_works.accounts.loan.step3"
        ]
    )
]

let transactionFeatures = [
    HowItWorksFeature(
        title: "how_it_works.transactions.add.title",
        summary: "how_it_works.transactions.add.summary",
        icon: "plus.circle",
        color: .green,
        steps: [
            "how_it_works.transactions.add.step1",
            "how_it_works.transactions.add.step2",
            "how_it_works.transactions.add.step3",
            "how_it_works.transactions.add.step4"
        ],
        animationView: AnyView(TransactionAnimationView())
    ),
    HowItWorksFeature(
        title: "how_it_works.transactions.installment.title",
        summary: "how_it_works.transactions.installment.summary",
        icon: "calendar.badge.plus",
        color: .orange,
        steps: [
            "how_it_works.transactions.installment.step1",
            "how_it_works.transactions.installment.step2",
            "how_it_works.transactions.installment.step3"
        ],
        tips: [
            "how_it_works.transactions.installment.tip1"
        ]
    ),
    HowItWorksFeature(
        title: "how_it_works.transactions.recurring.title",
        summary: "how_it_works.transactions.recurring.summary",
        icon: "arrow.triangle.2.circlepath",
        color: .cyan,
        steps: [
            "how_it_works.transactions.recurring.step1",
            "how_it_works.transactions.recurring.step2",
            "how_it_works.transactions.recurring.step3"
        ]
    )
]

let budgetFeatures = [
    HowItWorksFeature(
        title: "how_it_works.budgets.create.title",
        summary: "how_it_works.budgets.create.summary",
        icon: "chart.pie",
        color: .orange,
        steps: [
            "how_it_works.budgets.create.step1",
            "how_it_works.budgets.create.step2",
            "how_it_works.budgets.create.step3",
            "how_it_works.budgets.create.step4"
        ],
        isPremium: true,
        animationView: AnyView(BudgetAnimationView())
    ),
    HowItWorksFeature(
        title: "how_it_works.budgets.rollover.title",
        summary: "how_it_works.budgets.rollover.summary",
        icon: "arrow.forward.circle",
        color: .green,
        steps: [
            "how_it_works.budgets.rollover.step1",
            "how_it_works.budgets.rollover.step2",
            "how_it_works.budgets.rollover.step3"
        ],
        tips: [
            "how_it_works.budgets.rollover.tip1"
        ],
        isPremium: true
    )
]

let reportFeatures = [
    HowItWorksFeature(
        title: "how_it_works.reports.basic.title",
        summary: "how_it_works.reports.basic.summary",
        icon: "chart.bar",
        color: .pink,
        steps: [
            "how_it_works.reports.basic.step1",
            "how_it_works.reports.basic.step2",
            "how_it_works.reports.basic.step3"
        ]
    ),
    HowItWorksFeature(
        title: "how_it_works.reports.detailed.title",
        summary: "how_it_works.reports.detailed.summary",
        icon: "magnifyingglass",
        color: .purple,
        steps: [
            "how_it_works.reports.detailed.step1",
            "how_it_works.reports.detailed.step2",
            "how_it_works.reports.detailed.step3"
        ],
        isPremium: true
    )
]

let advancedFeatures = [
    HowItWorksFeature(
        title: "how_it_works.advanced.categories.title",
        summary: "how_it_works.advanced.categories.summary",
        icon: "folder",
        color: .orange,
        steps: [
            "how_it_works.advanced.categories.step1",
            "how_it_works.advanced.categories.step2",
            "how_it_works.advanced.categories.step3"
        ],
        tips: [
            "how_it_works.advanced.categories.tip1"
        ]
    ),
    HowItWorksFeature(
        title: "how_it_works.advanced.export.title",
        summary: "how_it_works.advanced.export.summary",
        icon: "square.and.arrow.up",
        color: .green,
        steps: [
            "how_it_works.advanced.export.step1",
            "how_it_works.advanced.export.step2",
            "how_it_works.advanced.export.step3"
        ],
        isPremium: true
    ),
    HowItWorksFeature(
        title: "how_it_works.advanced.notifications.title",
        summary: "how_it_works.advanced.notifications.summary",
        icon: "bell.badge",
        color: .red,
        steps: [
            "how_it_works.advanced.notifications.step1",
            "how_it_works.advanced.notifications.step2",
            "how_it_works.advanced.notifications.step3",
            "how_it_works.advanced.notifications.step4"
        ]
    )
]

// MARK: - Preview
#Preview {
    HowItWorksView()
        .environmentObject(AppSettings())
}
