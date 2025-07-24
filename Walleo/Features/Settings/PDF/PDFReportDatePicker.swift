// PDFReportDatePicker.swift
import SwiftUI
import SwiftData

struct PDFReportDatePicker: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appSettings: AppSettings
    
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var isGenerating = false
    @State private var shareableURL: ShareableURL?
    @State private var showError = false
    @State private var errorMessage = ""
    
    init() {
        let calendar = Calendar.current
        let now = Date()
        
        // Varsayılan olarak bu ayın başı ve sonu
        if let monthInterval = calendar.dateInterval(of: .month, for: now) {
            _startDate = State(initialValue: monthInterval.start)
            _endDate = State(initialValue: calendar.date(byAdding: .day, value: -1, to: monthInterval.end) ?? now)
        } else {
            _startDate = State(initialValue: now)
            _endDate = State(initialValue: now)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    HStack {
                        Text(LocalizedStringKey("pdf.report.start_date"))
                            .frame(width: 120, alignment: .leading)
                        Spacer()
                        DatePicker(
                            "",
                            selection: $startDate,
                            in: ...endDate,
                            displayedComponents: .date
                        )
                        .labelsHidden()
                    }
                    
                    HStack {
                        Text(LocalizedStringKey("pdf.report.end_date"))
                            .frame(width: 120, alignment: .leading)
                        Spacer()
                        DatePicker(
                            "",
                            selection: $endDate,
                            in: startDate...,
                            displayedComponents: .date
                        )
                        .labelsHidden()
                    }
                } header: {
                    Text(LocalizedStringKey("pdf.report.date_range"))
                } footer: {
                    Text(LocalizedStringKey("pdf.report.date_range_description"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(LocalizedStringKey("pdf.report.content_info"))
                                .font(.subheadline)
                                .foregroundColor(.primary)
                            
                            Text(LocalizedStringKey("pdf.report.content_details"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                // Hazır tarih aralıkları
                Section(LocalizedStringKey("pdf.report.quick_ranges")) {
                    Button(action: selectThisMonth) {
                        HStack {
                            Image(systemName: "calendar")
                            Text(LocalizedStringKey("pdf.report.this_month"))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Button(action: selectLastMonth) {
                        HStack {
                            Image(systemName: "calendar")
                            Text(LocalizedStringKey("pdf.report.last_month"))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Button(action: selectLast3Months) {
                        HStack {
                            Image(systemName: "calendar")
                            Text(LocalizedStringKey("pdf.report.last_3_months"))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Button(action: selectYearToDate) {
                        HStack {
                            Image(systemName: "calendar")
                            Text(LocalizedStringKey("pdf.report.year_to_date"))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            // Alt buton alanı
            VStack(spacing: 12) {
                Button(action: generateReport) {
                    if isGenerating {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text(LocalizedStringKey("pdf.report.generating"))
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    } else {
                        HStack {
                            Image(systemName: "doc.richtext.fill")
                            Text(LocalizedStringKey("pdf.report.generate"))
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                }
                .disabled(isGenerating)
                
                Text(LocalizedStringKey("pdf.report.generation_note"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .background(Color(.systemGroupedBackground))
        }
        .navigationTitle(LocalizedStringKey("pdf.report.title"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $shareableURL) { wrapper in
            ActivityView(activityItems: [wrapper.url])
                .onDisappear {
                    // Geçici dosyayı temizle
                    try? FileManager.default.removeItem(at: wrapper.url)
                }
        }
        .alert(LocalizedStringKey("pdf.report.error"), isPresented: $showError) {
            Button(LocalizedStringKey("common.ok")) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - Quick Date Selection
    private func selectThisMonth() {
        let calendar = Calendar.current
        if let monthInterval = calendar.dateInterval(of: .month, for: Date()) {
            startDate = monthInterval.start
            endDate = calendar.date(byAdding: .day, value: -1, to: monthInterval.end) ?? Date()
        }
    }
    
    private func selectLastMonth() {
        let calendar = Calendar.current
        if let lastMonth = calendar.date(byAdding: .month, value: -1, to: Date()),
           let monthInterval = calendar.dateInterval(of: .month, for: lastMonth) {
            startDate = monthInterval.start
            endDate = calendar.date(byAdding: .day, value: -1, to: monthInterval.end) ?? Date()
        }
    }
    
    private func selectLast3Months() {
        let calendar = Calendar.current
        endDate = Date()
        if let threeMonthsAgo = calendar.date(byAdding: .month, value: -3, to: endDate) {
            startDate = calendar.startOfDay(for: threeMonthsAgo)
        }
    }
    
    private func selectYearToDate() {
        let calendar = Calendar.current
        endDate = Date()
        if let yearStart = calendar.date(from: calendar.dateComponents([.year], from: endDate)) {
            startDate = yearStart
        }
    }
    
    // MARK: - Report Generation
    private func generateReport() {
        isGenerating = true
        
        Task {
            do {
                let service = PDFReportService(
                    modelContext: modelContext,
                    languageCode: appSettings.languageCode,
                    currencyCode: appSettings.currencyCode
                )
                
                if let pdfURL = await service.generateDetailedPDFReport(
                    startDate: startDate,
                    endDate: endDate
                ) {
                    await MainActor.run {
                        shareableURL = ShareableURL(url: pdfURL)
                        isGenerating = false
                    }
                } else {
                    await MainActor.run {
                        errorMessage = NSLocalizedString("pdf.report.generation_failed", comment: "")
                        showError = true
                        isGenerating = false
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    isGenerating = false
                }
            }
        }
    }
}
