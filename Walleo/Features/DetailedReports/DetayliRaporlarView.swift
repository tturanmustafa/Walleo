//
//  DetayliRaporlarView.swift
//  Walleo
//
//  Created by Mustafa Turan on 14.07.2025.
//


// DetayliRaporlarView.swift
import SwiftUI
import SwiftData

struct DetayliRaporlarView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appSettings: AppSettings
    
    @State private var baslangicTarihi: Date
    @State private var bitisTarihi: Date
    @State private var selectedReportType: ReportType? = nil
    @State private var showDatePicker = false
    @State private var datePickerType: DatePickerType = .start
    
    enum ReportType: String, CaseIterable {
        case creditCard = "detailed_reports.credit_card.title"
        case loan = "detailed_reports.loan.title"
        
        var icon: String {
            switch self {
            case .creditCard: return "creditcard.fill"
            case .loan: return "banknote.fill"
            }
        }
        
        var gradient: [Color] {
            switch self {
            case .creditCard: return [.purple, .pink]
            case .loan: return [.blue, .cyan]
            }
        }
    }
    
    enum DatePickerType {
        case start, end
    }
    
    init() {
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)!
        
        _baslangicTarihi = State(initialValue: startOfMonth)
        _bitisTarihi = State(initialValue: endOfMonth)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Gradient Background
                LinearGradient(
                    colors: [Color(.systemBackground), Color(.systemGray6)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Date Range Selector
                        dateRangeSelector
                            .padding(.horizontal)
                        
                        // Report Type Cards
                        VStack(spacing: 15) {
                            ForEach(ReportType.allCases, id: \.self) { type in
                                reportTypeCard(type)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                    }
                    .padding(.top)
                }
            }
            .navigationTitle("detailed_reports.title")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showDatePicker) {
                datePickerSheet
            }
            .fullScreenCover(item: $selectedReportType) { type in
                Group {
                    switch type {
                    case .creditCard:
                        KrediKartiRaporView(
                            baslangicTarihi: baslangicTarihi,
                            bitisTarihi: bitisTarihi,
                            modelContext: modelContext
                        )
                    case .loan:
                        KrediRaporView(
                            baslangicTarihi: baslangicTarihi,
                            bitisTarihi: bitisTarihi,
                            modelContext: modelContext
                        )
                    }
                }
                .environmentObject(appSettings)
            }
        }
    }
    
    private var dateRangeSelector: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // Start Date
                dateButton(
                    title: "detailed_reports.date_range.start",
                    date: baslangicTarihi,
                    type: .start
                )
                
                Image(systemName: "arrow.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // End Date
                dateButton(
                    title: "detailed_reports.date_range.end",
                    date: bitisTarihi,
                    type: .end
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
        )
    }
    
    private func dateButton(title: LocalizedStringKey, date: Date, type: DatePickerType) -> some View {
        Button(action: {
            datePickerType = type
            showDatePicker = true
        }) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(date.formatted(date: .abbreviated, time: .omitted))
                    .font(.callout.bold())
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.systemGray6))
            )
        }
    }
    
    private func reportTypeCard(_ type: ReportType) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                selectedReportType = type
            }
        }) {
            HStack(spacing: 16) {
                // Icon with gradient background
                ZStack {
                    LinearGradient(
                        colors: type.gradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    
                    Image(systemName: type.icon)
                        .font(.title2)
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(LocalizedStringKey(type.rawValue))
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(LocalizedStringKey(type.rawValue + ".description"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
    
    private var datePickerSheet: some View {
        NavigationStack {
            VStack {
                DatePicker(
                    "",
                    selection: datePickerType == .start ? $baslangicTarihi : $bitisTarihi,
                    in: datePickerType == .start ? ...bitisTarihi : baslangicTarihi...,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .padding()
                
                Spacer()
            }
            .navigationTitle(datePickerType == .start ? "detailed_reports.date_range.start" : "detailed_reports.date_range.end")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.done") {
                        showDatePicker = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// Custom Button Style
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}