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
        
        // --- HATA DÜZELTMESİ (SON ADIM) ---
        // Adım 1: Sorguda kullanılacak değerleri yerel sabitlere ata.
        let giderTuruRaw = IslemTuru.gider.rawValue
        let baslangicTarihi = monthInterval.start
        let bitisTarihi = monthInterval.end
        
        // Adım 2: Predicate içinde bu basit sabitleri kullan.
        let basitPredicate = #Predicate<Islem> { islem in
            islem.turRawValue == giderTuruRaw &&
            islem.tarih >= baslangicTarihi &&
            islem.tarih < bitisTarihi
        }
        // --- DÜZELTME SONU ---
        
        let tumAylikGiderler = try context.fetch(FetchDescriptor<Islem>(predicate: basitPredicate))
        
        let harcamalar = tumAylikGiderler.filter { islem in
            guard let kategori = islem.kategori else { return false }
            return kategoriIDleri.contains(kategori.id)
        }
        
        let toplamHarcama = harcamalar.reduce(0) { $0 + $1.tutar }
        
        guard budget.limitTutar > 0 else { return }
        
        let harcamaYuzdesi = (toplamHarcama / budget.limitTutar)
        
        if harcamaYuzdesi >= 1.0 {
            let baslik = NSLocalizedString("notification.budget.over_limit.title", comment: "")
            let formatString = NSLocalizedString("notification.budget.over_limit.body_format", comment: "")
            
            let limitString = formatCurrency(amount: budget.limitTutar, currencyCode: settings.currencyCode, localeIdentifier: settings.languageCode)
            let asimString = formatCurrency(amount: toplamHarcama - budget.limitTutar, currencyCode: settings.currencyCode, localeIdentifier: settings.languageCode)
            
            let aciklama = String(format: formatString, budget.isim, limitString, asimString)
            
            createNotification(tur: .butceLimitiAsildi, baslik: baslik, aciklama: aciklama, hedefID: budget.id)
            return
        }
        
        if harcamaYuzdesi >= settings.budgetAlertThreshold {
            let baslik = NSLocalizedString("notification.budget.approaching_limit.title", comment: "")
            let formatString = NSLocalizedString("notification.budget.approaching_limit.body_format", comment: "")
            
            let limitString = formatCurrency(amount: budget.limitTutar, currencyCode: settings.currencyCode, localeIdentifier: settings.languageCode)
            let yuzdeString = String(format: "%%%.0f", harcamaYuzdesi * 100)

            let aciklama = String(format: formatString, budget.isim, limitString, yuzdeString)

            createNotification(tur: .butceLimitiYaklasti, baslik: baslik, aciklama: aciklama, hedefID: budget.id)
        }
    }
    
    // MARK: - Kredi Taksit Kontrolleri
    func checkLoanInstallments() {
        // İskelet
    }
    
    func checkCreditCardDueDates() {
        guard let context = modelContext, let settings = appSettings else { return }
        guard settings.masterNotificationsEnabled else { return } // Faz 2'de bu ayarı ekleyeceğiz
        do {
            let descriptor = FetchDescriptor<Hesap>()
            let accounts = try context.fetch(descriptor)
            
            for account in accounts {
                // Sadece kredi kartı olan hesaplarla ilgileniyoruz.
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
        
        // Bu ayki kesim gününün tarihini hesapla
        let statementDayComponent = calendar.component(.day, from: statementDate)
        var components = calendar.dateComponents([.year, .month], from: today)
        components.day = statementDayComponent
        
        guard let thisMonthStatementDate = calendar.date(from: components) else { return }
            // Eğer bu ayki kesim tarihi geçtiyse, sonraki ayın kesim tarihini baz al.
        let upcomingStatementDate = thisMonthStatementDate < today ? calendar.date(byAdding: .month, value: 1, to: thisMonthStatementDate)! : thisMonthStatementDate
            
        // Son ödeme gününü hesapla
        guard let dueDate = calendar.date(byAdding: .day, value: dueDayOffset, to: upcomingStatementDate) else { return }
            
        // Hatırlatma penceresinde miyiz?
        let daysUntilDue = calendar.dateComponents([.day], from: today, to: dueDate).day ?? -1
            
        // Eğer son ödeme gününe 'ayarlardaki gün sayısı' kadar veya daha az kaldıysa ve gün geçmemişse
        if daysUntilDue >= 0 && daysUntilDue <= settings.loanReminderDays { // Şimdilik kredi hatırlatıcı ayarını kullanıyoruz
            let baslik = "\(account.isim) Son Ödeme Günü Yaklaşıyor"
            let aciklama = "Son ödeme tarihiniz: \(dueDate.formatted(date: .long, time: .omitted))."
                
            // TODO: Daha önce aynı hatırlatıcıdan oluşturulmuş mu diye kontrol eklenebilir.
            createNotification(tur: .krediKartiOdemeGunu, baslik: baslik, aciklama: aciklama, hedefID: account.id)
        }
    }

    // MARK: - Bildirim Oluşturma
    private func createNotification(tur: BildirimTuru, baslik: String, aciklama: String, hedefID: UUID) {
        guard let context = modelContext else { return }
        let yeniBildirim = Bildirim(tur: tur, baslik: baslik, aciklama: aciklama, hedefID: hedefID)
        context.insert(yeniBildirim)
        print("BİLDİRİM OLUŞTURULDU: \(baslik)")
    }
}
