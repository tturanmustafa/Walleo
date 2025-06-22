//
//  BildirimAyarlariView.swift
//  Walleo
//
//  Created by Mustafa Turan on 22.06.2025.
//


import SwiftUI

struct BildirimAyarlariView: View {
    @EnvironmentObject var appSettings: AppSettings
    
    // Bütçe eşiği için seçenekler
    private let budgetThresholdOptions = [
        (key: "settings.notifications.threshold.option_80", value: 0.80),
        (key: "settings.notifications.threshold.option_85", value: 0.85),
        (key: "settings.notifications.threshold.option_90", value: 0.90),
        (key: "settings.notifications.threshold.option_95", value: 0.95)
    ]

    var body: some View {
        Form {
            Section(header: Text("settings.notifications.master_section")) {
                Toggle("settings.notifications.master_toggle", isOn: $appSettings.masterNotificationsEnabled.animation())
            }

            Section(header: Text("settings.notifications.budget_section")) {
                Toggle("settings.notifications.budget_toggle", isOn: $appSettings.budgetAlertsEnabled)
                
                // Bütçe uyarıları açıksa, eşik ayarını göster
                if appSettings.budgetAlertsEnabled {
                    Picker("settings.notifications.threshold_picker", selection: $appSettings.budgetAlertThreshold) {
                        ForEach(budgetThresholdOptions, id: \.value) { option in
                            Text(LocalizedStringKey(option.key)).tag(option.value)
                        }
                    }
                }
            }
            .disabled(!appSettings.masterNotificationsEnabled) // Ana anahtar kapalıysa bu bölümü pasif yap

            Section(header: Text("settings.notifications.loan_section")) {
                Toggle("settings.notifications.loan_toggle", isOn: $appSettings.loanRemindersEnabled)

                // Kredi hatırlatıcısı açıksa, gün ayarını göster
                if appSettings.loanRemindersEnabled {
                    Stepper(
                        String.localizedStringWithFormat(NSLocalizedString("settings.notifications.loan_stepper", comment: ""), appSettings.loanReminderDays),
                        value: $appSettings.loanReminderDays,
                        in: 1...10
                    )
                }
            }
            .disabled(!appSettings.masterNotificationsEnabled) // Ana anahtar kapalıysa bu bölümü pasif yap
            // --- YENİ EKLENEN BÖLÜM ---
            Section(header: Text(LocalizedStringKey("settings.notifications.credit_card_section"))) {
                // Bu ayarı AppSettings'e eklememiz gerekecek
                Toggle("settings.notifications.credit_card_toggle", isOn: .constant(true))
            }
            .disabled(!appSettings.masterNotificationsEnabled)
        }
        .navigationTitle("settings.notifications.title")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        BildirimAyarlariView()
            .environmentObject(AppSettings())
            .environment(\.locale, .init(identifier: "tr"))
    }
}
