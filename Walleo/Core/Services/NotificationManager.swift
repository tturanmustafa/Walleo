import Foundation
import SwiftData
import UserNotifications

@MainActor
class NotificationManager {
    
    static let shared = NotificationManager()
    
    private var modelContext: ModelContext?
    private var appSettings: AppSettings?
    
    private init() {}
    
    func configure(modelContext: ModelContext, appSettings: AppSettings) {
        self.modelContext = modelContext
        self.appSettings = appSettings
    }
    
    // MARK: - İzin Yönetimi
    
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error = error {
                Logger.log("Bildirim izni alınırken hata: \(error.localizedDescription)", log: Logger.service, type: .error)
            }
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }
    
    // MARK: - Jenerik Hatırlatıcılar
    
    func scheduleGenericReminders() {
        let center = UNUserNotificationCenter.current()
        cancelGenericReminders()
        
        // 1. Günlük Gider Girme Hatırlatıcısı (21:00)
        let dailyContent = UNMutableNotificationContent()
        dailyContent.title = getLocalizedString("notification.daily.title")
        dailyContent.body = getLocalizedString("notification.daily.body")
        dailyContent.sound = .default
        
        var dailyDateComponents = DateComponents()
        dailyDateComponents.hour = 19
        dailyDateComponents.minute = 10
        let dailyTrigger = UNCalendarNotificationTrigger(dateMatching: dailyDateComponents, repeats: true)
        
        let dailyRequest = UNNotificationRequest(identifier: "walleoDailyReminder", content: dailyContent, trigger: dailyTrigger)
        center.add(dailyRequest) { error in
            if let error = error {
                Logger.log("Günlük bildirim kurulamadı: \(error.localizedDescription)", log: Logger.service, type: .error)
            } else {
                Logger.log("Günlük bildirim başarıyla kuruldu.", log: Logger.service)
            }
        }
        
        // 2. Haftalık Rapor Hatırlatıcısı (Pazartesi 10:00)
        let weeklyContent = UNMutableNotificationContent()
        weeklyContent.title = getLocalizedString("notification.weekly.title")
        weeklyContent.body = getLocalizedString("notification.weekly.body")
        weeklyContent.sound = .default
        
        var weeklyDateComponents = DateComponents()
        weeklyDateComponents.weekday = 2
        weeklyDateComponents.hour = 10
        weeklyDateComponents.minute = 0
        let weeklyTrigger = UNCalendarNotificationTrigger(dateMatching: weeklyDateComponents, repeats: true)
        
        let weeklyRequest = UNNotificationRequest(identifier: "walleoWeeklyReportReminder", content: weeklyContent, trigger: weeklyTrigger)
        center.add(weeklyRequest) { error in
            if let error = error {
                Logger.log("Haftalık bildirim kurulamadı: \(error.localizedDescription)", log: Logger.service, type: .error)
            } else {
                Logger.log("Haftalık bildirim başarıyla kuruldu.", log: Logger.service)
            }
        }
    }
    
    func cancelGenericReminders() {
        let center = UNUserNotificationCenter.current()
        let identifiers = ["walleoDailyReminder", "walleoWeeklyReportReminder"]
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        Logger.log("Genel hatırlatıcılar iptal edildi.", log: Logger.service)
    }
    
    // MARK: - Ödeme Günü Kontrolleri
    
    func checkLoanInstallments() {
        guard let context = modelContext, let settings = appSettings else { return }
        guard settings.masterNotificationsEnabled && settings.loanRemindersEnabled else { return }
        
        do {
            let descriptor = FetchDescriptor<Hesap>()
            let accounts = try context.fetch(descriptor)
            
            for account in accounts {
                if case .kredi(_, _, _, _, _, let taksitler) = account.detay {
                    checkUpcomingInstallments(for: account, taksitler: taksitler, settings: settings)
                }
            }
        } catch {
            Logger.log("Kredi taksitleri kontrol edilirken hata: \(error)", log: Logger.service, type: .error)
        }
    }
    
    private func checkUpcomingInstallments(for account: Hesap, taksitler: [KrediTaksitDetayi], settings: AppSettings) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        for taksit in taksitler where !taksit.odendiMi {
            let daysUntilDue = calendar.dateComponents([.day], from: today, to: taksit.odemeTarihi).day ?? 0
            
            if daysUntilDue >= 0 && daysUntilDue <= settings.loanReminderDays {
                // App içi bildirim oluştur
                let yeniBildirim = Bildirim(
                    tur: .taksitHatirlatici,
                    hedefID: account.id,
                    ilgiliIsim: account.isim,
                    tutar1: taksit.taksitTutari,
                    tarih1: taksit.odemeTarihi
                )
                modelContext?.insert(yeniBildirim)  // ✅ context yerine modelContext
                
                // Local notification planla
                scheduleLoanNotification(
                    accountName: account.isim,
                    amount: taksit.taksitTutari,
                    dueDate: taksit.odemeTarihi,
                    notificationID: "\(account.id)-\(taksit.id)"
                )
            }
        }
    }
    
    func checkCreditCardDueDates() {
        guard let context = modelContext, let settings = appSettings else { return }
        guard settings.masterNotificationsEnabled && settings.creditCardRemindersEnabled else { return }
        
        do {
            let descriptor = FetchDescriptor<Hesap>()
            let accounts = try context.fetch(descriptor)
            
            for account in accounts {
                if case .krediKarti(_, let kesimTarihi, let ofset) = account.detay {
                    calculateAndCreateNotification(for: account, statementDate: kesimTarihi, dueDayOffset: ofset, settings: settings)
                }
            }
        } catch {
            print("Kredi kartı hesapları çekilirken hata: \(error)")
        }
    }
    
    private func calculateAndCreateNotification(for account: Hesap, statementDate: Date, dueDayOffset: Int, settings: AppSettings) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        let statementDayComponent = calendar.component(.day, from: statementDate)
        var components = calendar.dateComponents([.year, .month], from: today)
        components.day = statementDayComponent
        
        guard let thisMonthStatementDate = calendar.date(from: components) else { return }
        
        let upcomingStatementDate = thisMonthStatementDate < today ? calendar.date(byAdding: .month, value: 1, to: thisMonthStatementDate)! : thisMonthStatementDate
        
        guard let dueDate = calendar.date(byAdding: .day, value: dueDayOffset, to: upcomingStatementDate) else { return }
        
        let daysUntilDue = calendar.dateComponents([.day], from: today, to: dueDate).day ?? -1
        
        if daysUntilDue >= 0 && daysUntilDue <= settings.creditCardReminderDays {
            // App içi bildirim
            createNotification(
                tur: .krediKartiOdemeGunu,
                hedefID: account.id,
                ilgiliIsim: account.isim,
                tarih1: dueDate
            )
            
            // Local notification
            scheduleCreditCardNotification(
                accountName: account.isim,
                dueDate: dueDate,
                notificationID: "creditcard-\(account.id)-\(dueDate.timeIntervalSince1970)"
            )
        }
    }
    
    // MARK: - Local Notification'lar
    
    private func getLocalizedString(_ key: String) -> String {
        guard let settings = appSettings else { return key }
        let languageBundle = Bundle.getLanguageBundle(for: settings.languageCode)
        return languageBundle.localizedString(forKey: key, value: key, table: nil)
    }
    
    private func scheduleLoanNotification(accountName: String, amount: Double, dueDate: Date, notificationID: String) {
        guard let settings = appSettings else { return }
        
        let content = UNMutableNotificationContent()
        content.title = getLocalizedString("notification.loan.due.title")
        
        let amountStr = formatCurrency(
            amount: amount,
            currencyCode: settings.currencyCode,
            localeIdentifier: settings.languageCode
        )
        
        let bodyFormat = getLocalizedString("notification.loan.due.body")
        content.body = String(format: bodyFormat, accountName, amountStr)
        content.sound = .default
        content.badge = NSNumber(value: getBadgeCount() + 1)
        
        guard let notificationDate = Calendar.current.date(
            byAdding: .day,
            value: -settings.loanReminderDays,
            to: dueDate
        ) else { return }
        
        var dateComponents = Calendar.current.dateComponents([.year, .month, .day], from: notificationDate)
        dateComponents.hour = 9
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(identifier: notificationID, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                Logger.log("Kredi bildirimi planlanamadı: \(error)", log: Logger.service, type: .error)
            }
        }
    }
    
    private func scheduleCreditCardNotification(accountName: String, dueDate: Date, notificationID: String) {
        guard let settings = appSettings else { return }
        
        let content = UNMutableNotificationContent()
        content.title = getLocalizedString("notification.credit_card.due.title")
        
        let dateStr = dueDate.formatted(Date.FormatStyle(date: .long, time: .omitted, locale: Locale(identifier: settings.languageCode)))
        let bodyFormat = getLocalizedString("notification.credit_card.due.body")
        content.body = String(format: bodyFormat, accountName, dateStr)
        
        content.sound = .default
        content.badge = NSNumber(value: getBadgeCount() + 1)
        
        guard let notificationDate = Calendar.current.date(
            byAdding: .day,
            value: -settings.creditCardReminderDays,
            to: dueDate
        ) else { return }
        
        var dateComponents = Calendar.current.dateComponents([.year, .month, .day], from: notificationDate)
        dateComponents.hour = 9
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(identifier: notificationID, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request)
    }
    
    func scheduleBudgetNotification(budgetName: String, percentage: Double, notificationID: String) {
        let content = UNMutableNotificationContent()
        
        content.title = getLocalizedString("notification.budget.warning.title")
        let bodyFormat = getLocalizedString("notification.budget.warning.body")
        content.body = String(format: bodyFormat, budgetName, Int(percentage * 100))
        
        content.sound = .default
        content.badge = NSNumber(value: getBadgeCount() + 1)
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: notificationID, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request)
    }
    
    // MARK: - Badge Yönetimi
    
    private func getBadgeCount() -> Int {
        guard let context = modelContext else { return 0 }
        let predicate = #Predicate<Bildirim> { !$0.okunduMu }
        let descriptor = FetchDescriptor(predicate: predicate)
        return (try? context.fetchCount(descriptor)) ?? 0
    }
    
    func updateBadgeCount() {
        let count = getBadgeCount()
        UNUserNotificationCenter.current().setBadgeCount(count)
    }
    
    // MARK: - Bildirim Oluşturma
    
    private func createNotification(tur: BildirimTuru, hedefID: UUID?, ilgiliIsim: String?, tutar1: Double? = nil, tutar2: Double? = nil, tarih1: Date? = nil) {
        guard let modelContext = modelContext else { return }
        
        let yeniBildirim = Bildirim(tur: tur, hedefID: hedefID, ilgiliIsim: ilgiliIsim, tutar1: tutar1, tutar2: tutar2, tarih1: tarih1)
        modelContext.insert(yeniBildirim)
        print("BİLDİRİM OLUŞTURULDU (HAM VERİ): \(yeniBildirim)")
    }
}
