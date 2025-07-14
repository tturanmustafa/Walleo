//
//  MonthNavigatorView.swift
//  Budgee
//
//  Created by Mustafa Turan on 18.06.2025.
//


import SwiftUI

struct MonthNavigatorView: View {
    @EnvironmentObject var appSettings: AppSettings
    @Binding var currentDate: Date
    @State private var ayYilSeciciGosteriliyor = false

    var body: some View {
        HStack {
            Button(action: { changeMonth(by: -1) }) { Image(systemName: "chevron.left") }
            Spacer()
            Text(monthYearString(from: currentDate, localeIdentifier: appSettings.languageCode))
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .onTapGesture { ayYilSeciciGosteriliyor = true }
            Spacer()
            Button(action: { changeMonth(by: 1) }) { Image(systemName: "chevron.right") }
        }
        .font(.title3)
        .foregroundColor(.secondary)
        .padding(.horizontal, 30)
        .padding(.top)
        .sheet(isPresented: $ayYilSeciciGosteriliyor) {
            AyYilSeciciView(currentDate: currentDate) { yeniTarih in
                currentDate = yeniTarih
            }
            .presentationDetents([.height(300)])
            .environmentObject(appSettings)
        }
    }
    
    private func changeMonth(by value: Int) {
        if let newDate = Calendar.current.date(byAdding: .month, value: value, to: currentDate) {
            currentDate = newDate
        }
    }
}