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
        
        // --- HATA DÜZELTMESİ: 'titleLocalizationKey' yerine doğrudan 'title' ve 'body' kullanıyoruz ---
        // Bu yöntem, tüm iOS versiyonlarında kararlı bir şekilde çalışır.
        
        // 1. Günlük Gider Girme Hatırlatıcısı (21:00)
        let dailyContent = UNMutableNotificationContent()
        dailyContent.title = NSLocalizedString("notification.daily.title", comment: "Daily reminder title")
        dailyContent.body = NSLocalizedString("notification.daily.body", comment: "Daily reminder body")
        dailyContent.sound = .default

        var dailyDateComponents = DateComponents()
        dailyDateComponents.hour = 21
        dailyDateComponents.minute = 0
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
        weeklyContent.title = NSLocalizedString("notification.weekly.title", comment: "Weekly report title")
        weeklyContent.body = NSLocalizedString("notification.weekly.body", comment: "Weekly report body")
        weeklyContent.sound = .default

        var weeklyDateComponents = DateComponents()
        weeklyDateComponents.weekday = 2 // 1 = Pazar, 2 = Pazartesi
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
        // Gelecekteki fazlar için iskelet
    }
    
    func checkCreditCardDueDates() {
        guard let context = modelContext, let settings = appSettings else { return }
        guard settings.masterNotificationsEnabled else { return }

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
        
        if daysUntilDue >= 0 && daysUntilDue <= settings.loanReminderDays {
            createNotification(
                tur: .krediKartiOdemeGunu,
                hedefID: account.id,
                ilgiliIsim: account.isim,
                tarih1: dueDate
            )
        }
    }

    // MARK: - Bildirim Oluşturma
    
    private func createNotification(tur: BildirimTuru, hedefID: UUID?, ilgiliIsim: String?, tutar1: Double? = nil, tutar2: Double? = nil, tarih1: Date? = nil) {
        guard let context = modelContext else { return }
        
        let yeniBildirim = Bildirim(tur: tur, hedefID: hedefID, ilgiliIsim: ilgiliIsim, tutar1: tutar1, tutar2: tutar2, tarih1: tarih1)
        context.insert(yeniBildirim)
        print("BİLDİRİM OLUŞTURULDU (HAM VERİ): \(yeniBildirim)")
    }
}
