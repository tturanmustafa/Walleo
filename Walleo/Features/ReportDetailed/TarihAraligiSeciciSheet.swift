//
//  TarihAraligiSeciciSheet.swift
//  Walleo
//
//  Created by Mustafa Turan on 14.07.2025.
//


import SwiftUI

struct TarihAraligiSeciciSheet: View {
    @Binding var baslangicTarihi: Date
    @Binding var bitisTarihi: Date
    @Environment(\.dismiss) private var dismiss
    
    @State private var tempBaslangic: Date
    @State private var tempBitis: Date
    
    init(baslangicTarihi: Binding<Date>, bitisTarihi: Binding<Date>) {
        self._baslangicTarihi = baslangicTarihi
        self._bitisTarihi = bitisTarihi
        self._tempBaslangic = State(initialValue: baslangicTarihi.wrappedValue)
        self._tempBitis = State(initialValue: bitisTarihi.wrappedValue)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Hazır Seçenekler
                VStack(spacing: 12) {
                    Text("detailed_reports.date_presets")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        PresetButton(title: "date_preset.this_week", action: selectThisWeek)
                        PresetButton(title: "date_preset.this_month", action: selectThisMonth)
                        PresetButton(title: "date_preset.last_3_months", action: selectLast3Months)
                        PresetButton(title: "date_preset.last_6_months", action: selectLast6Months)
                        PresetButton(title: "date_preset.this_year", action: selectThisYear)
                        PresetButton(title: "date_preset.last_year", action: selectLastYear)
                    }
                }
                
                Divider()
                
                // Manuel Tarih Seçimi
                VStack(spacing: 16) {
                    Text("detailed_reports.custom_range")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    DatePicker(
                        "detailed_reports.start_date",
                        selection: $tempBaslangic,
                        in: ...tempBitis,
                        displayedComponents: [.date]
                    )
                    
                    DatePicker(
                        "detailed_reports.end_date",
                        selection: $tempBitis,
                        in: tempBaslangic...,
                        displayedComponents: [.date]
                    )
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("detailed_reports.select_date_range")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.apply") {
                        baslangicTarihi = tempBaslangic
                        bitisTarihi = tempBitis
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Preset Actions
    
    private func selectThisWeek() {
        let calendar = Calendar.current
        if let weekInterval = calendar.dateInterval(of: .weekOfYear, for: Date()) {
            tempBaslangic = weekInterval.start
            tempBitis = calendar.date(byAdding: .day, value: -1, to: weekInterval.end) ?? weekInterval.end
        }
    }
    
    private func selectThisMonth() {
        let calendar = Calendar.current
        if let monthInterval = calendar.dateInterval(of: .month, for: Date()) {
            tempBaslangic = monthInterval.start
            tempBitis = calendar.date(byAdding: .day, value: -1, to: monthInterval.end) ?? monthInterval.end
        }
    }
    
    private func selectLast3Months() {
        let calendar = Calendar.current
        let now = Date()
        if let startDate = calendar.date(byAdding: .month, value: -3, to: now) {
            tempBaslangic = calendar.startOfDay(for: startDate)
            tempBitis = calendar.startOfDay(for: now)
        }
    }
    
    private func selectLast6Months() {
        let calendar = Calendar.current
        let now = Date()
        if let startDate = calendar.date(byAdding: .month, value: -6, to: now) {
            tempBaslangic = calendar.startOfDay(for: startDate)
            tempBitis = calendar.startOfDay(for: now)
        }
    }
    
    private func selectThisYear() {
        let calendar = Calendar.current
        if let yearInterval = calendar.dateInterval(of: .year, for: Date()) {
            tempBaslangic = yearInterval.start
            tempBitis = min(calendar.startOfDay(for: Date()), 
                          calendar.date(byAdding: .day, value: -1, to: yearInterval.end) ?? yearInterval.end)
        }
    }
    
    private func selectLastYear() {
        let calendar = Calendar.current
        if let lastYear = calendar.date(byAdding: .year, value: -1, to: Date()),
           let yearInterval = calendar.dateInterval(of: .year, for: lastYear) {
            tempBaslangic = yearInterval.start
            tempBitis = calendar.date(byAdding: .day, value: -1, to: yearInterval.end) ?? yearInterval.end
        }
    }
}

struct PresetButton: View {
    let title: LocalizedStringKey
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color(.systemGray6))
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}