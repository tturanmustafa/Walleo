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

    
    // MARK: - Ödeme Günü Kontrolleri
    
    func checkLoanInstallments() {
        // Gelecekteki fazlar için iskelet
    }
    
    func checkCreditCardDueDates() {
        guard let context = modelContext, let settings = appSettings else { return }
        // TODO: Kredi kartları için ayrı bir ayar eklendiğinde burası güncellenecek.
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
        
        // Şimdilik kredi hatırlatıcı ayarını kullanıyoruz (loanReminderDays)
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
        
        // TODO: Aynı hedef ve tür için yakın zamanda oluşturulmuş bir bildirim var mı diye kontrol ederek
        // mükerrer bildirimleri engelleme mantığı eklenebilir.
        
        let yeniBildirim = Bildirim(tur: tur, hedefID: hedefID, ilgiliIsim: ilgiliIsim, tutar1: tutar1, tutar2: tutar2, tarih1: tarih1)
        context.insert(yeniBildirim)
        print("BİLDİRİM OLUŞTURULDU (HAM VERİ): \(yeniBildirim)")
    }
}
