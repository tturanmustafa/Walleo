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

    // MARK: - Bütçe Kontrolleri
    
    func checkBudget(for transaction: Islem) {
        guard let context = modelContext, let settings = appSettings else {
            print("Hata: NotificationManager başlatılmamış.")
            return
        }
        
        guard transaction.tur == .gider, let transactionCategory = transaction.kategori else { return }
        guard settings.masterNotificationsEnabled, settings.budgetAlertsEnabled else { return }
        
        do {
            let butceDescriptor = FetchDescriptor<Butce>()
            let allBudgets = try context.fetch(butceDescriptor)
            
            let relevantBudgets = allBudgets.filter { budget in
                budget.kategoriler?.contains(where: { $0.id == transactionCategory.id }) ?? false
            }
            
            for budget in relevantBudgets {
                try? checkStatus(for: budget, in: context, with: settings)
            }
            
        } catch {
            print("Bütçe kontrolü sırasında hata: \(error)")
        }
    }
    
    private func checkStatus(for budget: Butce, in context: ModelContext, with settings: AppSettings) throws {
        let calendar = Calendar.current
        guard let monthInterval = calendar.dateInterval(of: .month, for: Date()) else { return }
        
        let kategoriIDleri = Set(budget.kategoriler?.map { $0.id } ?? [])
        guard !kategoriIDleri.isEmpty else { return }
        
        let giderTuruRaw = IslemTuru.gider.rawValue
        let baslangicTarihi = monthInterval.start
        let bitisTarihi = monthInterval.end
        
        let basitPredicate = #Predicate<Islem> { islem in
            islem.turRawValue == giderTuruRaw &&
            islem.tarih >= baslangicTarihi &&
            islem.tarih < bitisTarihi
        }
        
        let tumAylikGiderler = try context.fetch(FetchDescriptor<Islem>(predicate: basitPredicate))
        
        let harcamalar = tumAylikGiderler.filter { islem in
            guard let kategori = islem.kategori else { return false }
            return kategoriIDleri.contains(kategori.id)
        }
        
        let toplamHarcama = harcamalar.reduce(0) { $0 + $1.tutar }
        
        guard budget.limitTutar > 0 else { return }
        
        let harcamaYuzdesi = (toplamHarcama / budget.limitTutar)
        
        if harcamaYuzdesi >= 1.0 {
            createNotification(
                tur: .butceLimitiAsildi,
                hedefID: budget.id,
                ilgiliIsim: budget.isim,
                tutar1: budget.limitTutar,
                tutar2: toplamHarcama - budget.limitTutar
            )
            return
        }
        
        if harcamaYuzdesi >= settings.budgetAlertThreshold {
            createNotification(
                tur: .butceLimitiYaklasti,
                hedefID: budget.id,
                ilgiliIsim: budget.isim,
                tutar1: budget.limitTutar,
                tutar2: harcamaYuzdesi
            )
        }
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
