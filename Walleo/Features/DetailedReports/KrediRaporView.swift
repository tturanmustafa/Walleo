//
//  KrediRaporView.swift
//  Walleo
//
//  Created by Mustafa Turan on 14.07.2025.
//


// KrediRaporView.swift
import SwiftUI
import SwiftData
import Charts

struct KrediRaporView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appSettings: AppSettings
    @StateObject private var viewModel: KrediRaporViewModel
    
    @State private var selectedLoan: Hesap?
    @State private var showingDetail = false
    @State private var rotationDegrees: Double = 0
    @State private var expandedLoans = Set<UUID>()
    
    init(baslangicTarihi: Date, bitisTarihi: Date, modelContext: ModelContext) {
        _viewModel = StateObject(wrappedValue: KrediRaporViewModel(
            baslangicTarihi: baslangicTarihi,
            bitisTarihi: bitisTarihi,
            modelContext: modelContext
        ))
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Animated background
                ParticleBackgroundView()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Dashboard Summary
                        loanDashboard
                        
                        // Active Loans
                        activeLoansSection
                        
                        // Payment Calendar
                        paymentCalendar
                        
                        // Loan Comparison
                        if viewModel.loans.count > 1 {
                            loanComparison
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("detailed_reports.loan.title")
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
    
    private var loanDashboard: some View {
        VStack(spacing: 16) {
            Text("detailed_reports.loan.dashboard")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Glassmorphism cards
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                GlassmorphicCard(
                    title: "detailed_reports.loan.active_loans",
                    value: "\(viewModel.activeLoansCount)",
                    icon: "banknote",
                    gradient: [.blue, .cyan]
                )
                .rotation3DEffect(
                    .degrees(rotationDegrees),
                    axis: (x: 0, y: 1, z: 0)
                )
                
                GlassmorphicCard(
                    title: "detailed_reports.loan.total_remaining",
                    value: formatCurrency(amount: viewModel.totalRemaining, currencyCode: appSettings.currencyCode, localeIdentifier: appSettings.languageCode),
                    icon: "chart.line.downtrend",
                    gradient: [.orange, .red]
                )
                .rotation3DEffect(
                    .degrees(-rotationDegrees),
                    axis: (x: 0, y: 1, z: 0)
                )
                
                GlassmorphicCard(
                    title: "detailed_reports.loan.monthly_payment",
                    value: formatCurrency(amount: viewModel.monthlyPayment, currencyCode: appSettings.currencyCode, localeIdentifier: appSettings.languageCode),
                    icon: "calendar.badge.clock",
                    gradient: [.purple, .pink]
                )
                .rotation3DEffect(
                    .degrees(rotationDegrees),
                    axis: (x: 1, y: 0, z: 0)
                )
                
                GlassmorphicCard(
                    title: "detailed_reports.loan.paid_this_period",
                    value: formatCurrency(amount: viewModel.paidThisPeriod, currencyCode: appSettings.currencyCode, localeIdentifier: appSettings.languageCode),
                    icon: "checkmark.seal.fill",
                    gradient: [.green, .mint]
                )
                .rotation3DEffect(
                    .degrees(-rotationDegrees),
                    axis: (x: 1, y: 0, z: 0)
                )
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                rotationDegrees = 5
            }
        }
    }
    
    private var activeLoansSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("detailed_reports.loan.active_loans_section")
                .font(.headline)
            
            ForEach(viewModel.loanDetails) { loan in
                ExpandableLoanCard(
                    loan: loan,
                    isExpanded: expandedLoans.contains(loan.id),
                    onTap: {
                        withAnimation(.spring()) {
                            if expandedLoans.contains(loan.id) {
                                expandedLoans.remove(loan.id)
                            } else {
                                expandedLoans.insert(loan.id)
                            }
                        }
                    }
                )
            }
        }
    }
    
    private var paymentCalendar: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("detailed_reports.loan.payment_calendar")
                .font(.headline)
            
            PaymentCalendarView(payments: viewModel.upcomingPayments)
                .frame(height: 350)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
        )
    }
    
    private var loanComparison: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("detailed_reports.loan.comparison")
                .font(.headline)
            
            RadarChartView(loans: viewModel.loanDetails)
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

// Glassmorphic Card
struct GlassmorphicCard: View {
    let title: LocalizedStringKey
    let value: String
    let icon: String
    let gradient: [Color]
    
    @State private var isPressed = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(
                        LinearGradient(
                            colors: gradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Spacer()
            }
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.title3.bold())
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: gradient.map { $0.opacity(0.5) },
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
        )
        .scaleEffect(isPressed ? 0.95 : 1)
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isPressed = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isPressed = false
                }
            }
        }
    }
}

// Expandable Loan Card
struct ExpandableLoanCard: View {
    let loan: LoanDetail
    let isExpanded: Bool
    let onTap: () -> Void
    @EnvironmentObject var appSettings: AppSettings
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: onTap) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(loan.name)
                            .font(.headline)
                        Text("\(loan.paidInstallments)/\(loan.totalInstallments) taksit")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(formatCurrency(amount: loan.remainingAmount, currencyCode: appSettings.currencyCode, localeIdentifier: appSettings.languageCode))
                            .font(.headline)
                        Text("Kalan")
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
                VStack(spacing: 12) {
                    // Progress bars
                    ProgressSection(
                        title: "detailed_reports.loan.payment_progress",
                        value: Double(loan.paidInstallments),
                        total: Double(loan.totalInstallments),
                        color: .green
                    )
                    
                    // Period details
                    VStack(spacing: 8) {
                        DetailRow(
                            label: "detailed_reports.loan.period_payment",
                            value: formatCurrency(amount: loan.periodPayment, currencyCode: appSettings.currencyCode, localeIdentifier: appSettings.languageCode)
                        )
                        
                        DetailRow(
                            label: "detailed_reports.loan.unpaid_installments",
                            value: "\(loan.unpaidInstallments)"
                        )
                        
                        DetailRow(
                            label: "detailed_reports.loan.paid_as_expense",
                            value: formatCurrency(amount: loan.paidAsExpense, currencyCode: appSettings.currencyCode, localeIdentifier: appSettings.languageCode)
                        )
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6).opacity(0.5))
                    )
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
        )
    }
}

// Progress Section
struct ProgressSection: View {
    let title: LocalizedStringKey
    let value: Double
    let total: Double
    let color: Color
    
    var progress: Double {
        guard total > 0 else { return 0 }
        return value / total
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(Int(progress * 100))%")
                    .font(.caption.bold())
                    .foregroundColor(color)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geometry.size.width * progress, height: 8)
                }
            }
            .frame(height: 8)
        }
    }
}

// Detail Row
struct DetailRow: View {
    let label: LocalizedStringKey
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.callout)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.callout.bold())
        }
    }
}

// Payment Calendar View
struct PaymentCalendarView: View {
    let payments: [PaymentInfo]
    @State private var selectedPayment: PaymentInfo?
    
    var body: some View {
        VStack {
            // Calendar grid
            CalendarGridView(
                payments: payments,
                onSelectPayment: { payment in
                    withAnimation(.spring()) {
                        selectedPayment = payment
                    }
                }
            )
            
            // Selected payment detail
            if let payment = selectedPayment {
                PaymentDetailCard(payment: payment)
                    .transition(.asymmetric(
                        insertion: .scale.combined(with: .opacity),
                        removal: .scale.combined(with: .opacity)
                    ))
            }
        }
    }
}

// Particle Background
struct ParticleBackgroundView: View {
    @State private var particles: [Particle] = []
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(
                    colors: [
                        Color.blue.opacity(0.05),
                        Color.cyan.opacity(0.05)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                
                ForEach(particles) { particle in
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.blue.opacity(particle.opacity),
                                    Color.cyan.opacity(particle.opacity * 0.5)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: particle.size, height: particle.size)
                        .position(particle.position)
                        .blur(radius: particle.blur)
                }
            }
            .onAppear {
                createParticles(in: geometry.size)
            }
        }
        .ignoresSafeArea()
    }
    
    private func createParticles(in size: CGSize) {
        for _ in 0..<20 {
            let particle = Particle(
                position: CGPoint(
                    x: .random(in: 0...size.width),
                    y: .random(in: 0...size.height)
                ),
                size: .random(in: 20...80),
                opacity: .random(in: 0.1...0.3),
                blur: .random(in: 1...3)
            )
            particles.append(particle)
            
            animateParticle(particle, in: size)
        }
    }
    
    private func animateParticle(_ particle: Particle, in size: CGSize) {
        withAnimation(
            .linear(duration: .random(in: 10...20))
            .repeatForever(autoreverses: false)
        ) {
            if let index = particles.firstIndex(where: { $0.id == particle.id }) {
                particles[index].position = CGPoint(
                    x: .random(in: 0...size.width),
                    y: .random(in: 0...size.height)
                )
            }
        }
    }
}

struct Particle: Identifiable {
    let id = UUID()
    var position: CGPoint
    let size: CGFloat
    let opacity: Double
    let blur: CGFloat
}

// Placeholder views for complex components
struct RadarChartView: View {
    let loans: [LoanDetail]
    
    var body: some View {
        // Simplified radar chart representation
        GeometryReader { geometry in
            ZStack {
                // Radar grid
                ForEach(1..<6) { level in
                    Path { path in
                        for i in 0..<6 {
                            let angle = Double(i) * 60 * .pi / 180
                            let x = geometry.size.width / 2 + cos(angle) * Double(level * 30)
                            let y = geometry.size.height / 2 + sin(angle) * Double(level * 30)
                            
                            if i == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                        path.closeSubpath()
                    }
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                }
                
                // Loan data points
                ForEach(loans) { loan in
                    Path { path in
                        // Simplified data plotting
                        for i in 0..<6 {
                            let angle = Double(i) * 60 * .pi / 180
                            let value = Double.random(in: 0.3...0.9) // Replace with actual metrics
                            let x = geometry.size.width / 2 + cos(angle) * value * 150
                            let y = geometry.size.height / 2 + sin(angle) * value * 150
                            
                            if i == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                        path.closeSubpath()
                    }
                    .fill(loan.color.opacity(0.3))
                    .overlay(
                        Path { path in
                            // Same path for stroke
                            for i in 0..<6 {
                                let angle = Double(i) * 60 * .pi / 180
                                let value = Double.random(in: 0.3...0.9)
                                let x = geometry.size.width / 2 + cos(angle) * value * 150
                                let y = geometry.size.height / 2 + sin(angle) * value * 150
                                
                                if i == 0 {
                                    path.move(to: CGPoint(x: x, y: y))
                                } else {
                                    path.addLine(to: CGPoint(x: x, y: y))
                                }
                            }
                            path.closeSubpath()
                        }
                        .stroke(loan.color, lineWidth: 2)
                    )
                }
            }
        }
    }
}

struct CalendarGridView: View {
    let payments: [PaymentInfo]
    let onSelectPayment: (PaymentInfo) -> Void
    
    var body: some View {
        // Simplified calendar view
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 10) {
            ForEach(1..<32) { day in
                if let payment = payments.first(where: { Calendar.current.component(.day, from: $0.date) == day }) {
                    PaymentDayCell(day: day, payment: payment, onTap: {
                        onSelectPayment(payment)
                    })
                } else {
                    EmptyDayCell(day: day)
                }
            }
        }
    }
}

struct PaymentDayCell: View {
    let day: Int
    let payment: PaymentInfo
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(payment.isPaid ? Color.green.opacity(0.3) : Color.orange.opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(payment.isPaid ? Color.green : Color.orange, lineWidth: 2)
                    )
                
                VStack(spacing: 2) {
                    Text("\(day)")
                        .font(.caption.bold())
                    
                    Image(systemName: payment.isPaid ? "checkmark.circle.fill" : "clock.fill")
                        .font(.caption2)
                        .foregroundColor(payment.isPaid ? .green : .orange)
                }
            }
            .frame(height: 50)
        }
        .buttonStyle(.plain)
    }
}

struct EmptyDayCell: View {
    let day: Int
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray6))
            
            Text("\(day)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(height: 50)
    }
}

struct PaymentDetailCard: View {
    let payment: PaymentInfo
    @EnvironmentObject var appSettings: AppSettings
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(payment.loanName)
                    .font(.headline)
                Spacer()
                Image(systemName: payment.isPaid ? "checkmark.seal.fill" : "clock.badge.exclamationmark")
                    .foregroundColor(payment.isPaid ? .green : .orange)
            }
            
            HStack {
                Text("Tutar:")
                    .foregroundColor(.secondary)
                Spacer()
                Text(formatCurrency(amount: payment.amount, currencyCode: appSettings.currencyCode, localeIdentifier: appSettings.languageCode))
                    .font(.headline)
            }
            
            HStack {
                Text("Tarih:")
                    .foregroundColor(.secondary)
                Spacer()
                Text(payment.date.formatted(date: .long, time: .omitted))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
    }
}