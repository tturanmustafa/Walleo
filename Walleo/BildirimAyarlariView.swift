//
//  BildirimAyarlariView.swift
//  Walleo
//
//  Created by Mustafa Turan on 22.06.2025.
//


import SwiftUI

struct BildirimAyarlariView: View {
    @EnvironmentObject var appSettings: AppSettings
    
    private let budgetThresholdOptions = [
        (key: "settings.notifications.threshold.option_80", value: 0.80),
        (key: "settings.notifications.threshold.option_85", value: 0.85),
        (key: "settings.notifications.threshold.option_90", value: 0.90),
        (key: "settings.notifications.threshold.option_95", value: 0.95)
    ]
    
    // --- YENİ EKLENEN YARDIMCI DEĞİŞKEN ---
    // Stepper metnini doğru dilde oluşturan hesaplanmış değişken
    private var loanStepperLabel: String {
        let dilKodu = appSettings.languageCode
        
        guard let path = Bundle.main.path(forResource: dilKodu, ofType: "lproj"),
              let languageBundle = Bundle(path: path) else {
            return "\(appSettings.loanReminderDays)" // Hata durumunda sadece sayıyı göster
        }
        
        let formatString = languageBundle.localizedString(forKey: "settings.notifications.loan_stepper", value: "%d days before due date", table: nil)
        
        return String(format: formatString, appSettings.loanReminderDays)
    }
    // --- YENİ DEĞİŞKEN SONU ---

    var body: some View {
        Form {
            Section(header: Text(LocalizedStringKey("settings.notifications.master_section"))) {
                Toggle(LocalizedStringKey("settings.notifications.master_toggle"), isOn: $appSettings.masterNotificationsEnabled.animation())
            }

            Section(header: Text(LocalizedStringKey("settings.notifications.budget_section"))) {
                Toggle(LocalizedStringKey("settings.notifications.budget_toggle"), isOn: $appSettings.budgetAlertsEnabled)
                
                if appSettings.budgetAlertsEnabled {
                    Picker(LocalizedStringKey("settings.notifications.threshold_picker"), selection: $appSettings.budgetAlertThreshold) {
                        ForEach(budgetThresholdOptions, id: \.value) { option in
                            Text(LocalizedStringKey(option.key)).tag(option.value)
                        }
                    }
                }
            }
            .disabled(!appSettings.masterNotificationsEnabled)

            Section(header: Text(LocalizedStringKey("settings.notifications.loan_section"))) {
                Toggle(LocalizedStringKey("settings.notifications.loan_toggle"), isOn: $appSettings.loanRemindersEnabled)

                if appSettings.loanRemindersEnabled {
                    // --- GÜNCELLENEN SATIR ---
                    Stepper(loanStepperLabel, value: $appSettings.loanReminderDays, in: 1...10)
                }
            }
            .disabled(!appSettings.masterNotificationsEnabled)
            
            Section(header: Text(LocalizedStringKey("settings.notifications.credit_card_section"))) {
                // TODO: AppSettings'e kredi kartı için yeni bir @AppStorage eklenmeli
                Toggle(LocalizedStringKey("settings.notifications.credit_card_toggle"), isOn: .constant(true))
            }
            .disabled(!appSettings.masterNotificationsEnabled)
        }
        .navigationTitle(LocalizedStringKey("settings.notifications.title"))
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
