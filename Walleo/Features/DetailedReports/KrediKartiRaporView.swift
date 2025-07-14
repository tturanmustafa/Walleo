// KrediKartiRaporView.swift
import SwiftUI
import SwiftData
import Charts

struct KrediKartiRaporView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appSettings: AppSettings
    @StateObject private var viewModel: KrediKartiRaporViewModel
    
    @State private var selectedCard: Hesap?
    @State private var isRotating = false
    @State private var expandedSections = Set<String>()
    
    init(baslangicTarihi: Date, bitisTarihi: Date, modelContext: ModelContext) {
        _viewModel = StateObject(wrappedValue: KrediKartiRaporViewModel(
            baslangicTarihi: baslangicTarihi,
            bitisTarihi: bitisTarihi,
            modelContext: modelContext
        ))
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Animated gradient background
                AnimatedGradientBackground()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // 3D Credit Card Selector
                        creditCardSelector
                        
                        if selectedCard != nil {
                            // Overview Card with 3D effect
                            overviewCard
                                .transition(.asymmetric(
                                    insertion: .scale.combined(with: .opacity),
                                    removal: .scale.combined(with: .opacity)
                                ))
                            
                            // Spending Trend Chart
                            spendingTrendChart
                            
                            // Category Analysis
                            categoryAnalysis
                            
                            // Heatmap Calendar
                            heatmapCalendar
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("detailed_reports.credit_card.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .task {
                await viewModel.loadData()
            }
        }
    }
    
    private var creditCardSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 15) {
                ForEach(viewModel.creditCards) { card in
                    CreditCard3DView(
                        card: card,
                        isSelected: selectedCard?.id == card.id,
                        onTap: {
                            withAnimation(.spring()) {
                                selectedCard = card
                                viewModel.selectCard(card)
                            }
                        }
                    )
                }
            }
            .padding(.horizontal)
        }
        .frame(height: 200)
    }
    
    private var overviewCard: some View {
        VStack(spacing: 16) {
            HStack {
                Text("detailed_reports.credit_card.overview")
                    .font(.headline)
                Spacer()
                Button(action: {
                    withAnimation(.spring()) {
                        isRotating.toggle()
                    }
                }) {
                    Image(systemName: "arrow.2.circlepath")
                        .rotationEffect(.degrees(isRotating ? 360 : 0))
                }
            }
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                MetricCard(
                    title: "detailed_reports.credit_card.total_spent",
                    value: formatCurrency(amount: viewModel.totalSpent, currencyCode: appSettings.currencyCode, localeIdentifier: appSettings.languageCode),
                    icon: "creditcard",
                    color: .red
                )
                
                MetricCard(
                    title: "detailed_reports.credit_card.daily_average",
                    value: formatCurrency(amount: viewModel.dailyAverage, currencyCode: appSettings.currencyCode, localeIdentifier: appSettings.languageCode),
                    icon: "calendar",
                    color: .blue
                )
                
                MetricCard(
                    title: "detailed_reports.credit_card.transaction_count",
                    value: "\(viewModel.transactionCount)",
                    icon: "list.bullet",
                    color: .green
                )
                
                MetricCard(
                    title: "detailed_reports.credit_card.largest_purchase",
                    value: formatCurrency(amount: viewModel.largestPurchase, currencyCode: appSettings.currencyCode, localeIdentifier: appSettings.languageCode),
                    icon: "arrow.up.circle",
                    color: .orange
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
        )
    }
    
    private var spendingTrendChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("detailed_reports.credit_card.spending_trend")
                .font(.headline)
            
            Chart(viewModel.dailySpending) { item in
                LineMark(
                    x: .value("Date", item.date),
                    y: .value("Amount", item.amount)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [.purple, .pink],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .interpolationMethod(.catmullRom)
                
                AreaMark(
                    x: .value("Date", item.date),
                    y: .value("Amount", item.amount)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [.purple.opacity(0.3), .pink.opacity(0.1)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)
            }
            .frame(height: 200)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
        )
    }
    
    private var categoryAnalysis: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("detailed_reports.credit_card.category_analysis")
                .font(.headline)
            
            ForEach(viewModel.categoryBreakdown) { category in
                ExpandableCategoryCard(
                    category: category,
                    isExpanded: expandedSections.contains(category.id.uuidString),
                    onTap: {
                        withAnimation(.spring()) {
                            if expandedSections.contains(category.id.uuidString) {
                                expandedSections.remove(category.id.uuidString)
                            } else {
                                expandedSections.insert(category.id.uuidString)
                            }
                        }
                    }
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
        )
    }
    
    private var heatmapCalendar: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("detailed_reports.credit_card.spending_heatmap")
                .font(.headline)
            
            SpendingHeatmapView(data: viewModel.heatmapData)
                .frame(height: 300)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
        )
    }
}

// 3D Credit Card View
struct CreditCard3DView: View {
    let card: Hesap
    let isSelected: Bool
    let onTap: () -> Void
    
    @State private var rotationAngle: Double = 0
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [card.renk, card.renk.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 300, height: 180)
                .overlay(
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "creditcard.fill")
                                .font(.title2)
                            Spacer()
                            Text("VISA")
                                .font(.title3.bold())
                        }
                        .foregroundColor(.white.opacity(0.9))
                        
                        Spacer()
                        
                        Text("•••• •••• •••• ••••")
                            .font(.title3)
                            .foregroundColor(.white.opacity(0.8))
                            .tracking(2)
                        
                        Text(card.isim)
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    .padding()
                )
                .rotation3DEffect(
                    .degrees(rotationAngle),
                    axis: (x: 0, y: 1, z: 0)
                )
                .scaleEffect(isSelected ? 1.05 : 0.95)
                .shadow(
                    color: isSelected ? card.renk.opacity(0.5) : .clear,
                    radius: isSelected ? 20 : 10,
                    y: isSelected ? 10 : 5
                )
        }
        .onTapGesture(perform: onTap)
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                rotationAngle = 10
            }
        }
    }
}

// Metric Card Component
struct MetricCard: View {
    let title: LocalizedStringKey
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(color)
                Spacer()
            }
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.title3.bold())
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
}

// Expandable Category Card
struct ExpandableCategoryCard: View {
    let category: CategoryBreakdown
    let isExpanded: Bool
    let onTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: onTap) {
                HStack {
                    Image(systemName: category.icon)
                        .font(.title3)
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(category.color)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(LocalizedStringKey(category.name))
                            .font(.headline)
                        Text("\(category.transactionCount) transactions")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(category.formattedAmount)
                            .font(.headline)
                        Text("\(Int(category.percentage))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Image(systemName: "chevron.right")
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                VStack(spacing: 8) {
                    ForEach(category.transactions.prefix(5)) { transaction in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(transaction.isim)
                                    .font(.callout)
                                Text(transaction.tarih.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text(formatCurrency(amount: transaction.tutar, currencyCode: "TRY", localeIdentifier: "tr"))
                                .font(.callout.bold())
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6).opacity(0.5))
        )
    }
}

// Animated Gradient Background
struct AnimatedGradientBackground: View {
    @State private var animateGradient = false
    
    var body: some View {
        LinearGradient(
            colors: [
                Color.purple.opacity(0.1),
                Color.pink.opacity(0.1),
                Color.blue.opacity(0.1)
            ],
            startPoint: animateGradient ? .topLeading : .bottomLeading,
            endPoint: animateGradient ? .bottomTrailing : .topTrailing
        )
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.linear(duration: 5).repeatForever(autoreverses: true)) {
                animateGradient.toggle()
            }
        }
    }
}

// Spending Heatmap View
struct SpendingHeatmapView: View {
    let data: [[Double]]
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 2) {
                ForEach(0..<7, id: \.self) { row in
                    HStack(spacing: 2) {
                        ForEach(0..<24, id: \.self) { col in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(heatmapColor(for: data[safe: row]?[safe: col] ?? 0))
                                .frame(
                                    width: (geometry.size.width - 48) / 24,
                                    height: (geometry.size.height - 14) / 7
                                )
                        }
                    }
                }
            }
        }
    }
    
    private func heatmapColor(for value: Double) -> Color {
        let intensity = min(value / 1000, 1.0)
        return Color.red.opacity(0.1 + intensity * 0.8)
    }
}

// Safe array access extension
extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
