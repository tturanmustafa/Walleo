//
//  DonemHarcamaOzetKarti.swift
//  Walleo
//
//  Created by Mustafa Turan on 27.06.2025.
//


import SwiftUI

struct DonemHarcamaOzetKarti: View {
    @EnvironmentObject var appSettings: AppSettings
    let toplamTutar: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(LocalizedStringKey("credit_card_details.total_expenses_for_period"))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fontWeight(.medium)

            Text(formatCurrency(amount: toplamTutar, currencyCode: appSettings.currencyCode, localeIdentifier: appSettings.languageCode))
                .font(.title2.bold())
                .foregroundColor(.red) // Harcamayı temsil ettiği için kırmızı
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}