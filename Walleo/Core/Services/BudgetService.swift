// Dosya: BudgetService.swift

import Foundation
import SwiftData

@MainActor
class BudgetService {
    
    static let shared = BudgetService()
    private init() {}
    
    func runBudgetChecks(for transaction: Islem, in context: ModelContext, settings: AppSettings) {
        guard transaction.tur == .gider, let transactionCategory = transaction.kategori else { return }
        guard settings.masterNotificationsEnabled, settings.budgetAlertsEnabled else { return }
        
        do {
            // 1. ADIM (DÜZELTME): TÜM bütçeleri karmaşık bir filtre OLMADAN çek.
            let allBudgets = try context.fetch(FetchDescriptor<Butce>())
            
            // 2. ADIM (YENİ): İlgili bütçeleri kod içinde, hafızada filtrele.
            // Bu yöntem %100 güvenilirdir ve derleme hatası vermez.
            let categoryID = transactionCategory.id
            let relevantBudgets = allBudgets.filter { budget in
                // budget.kategoriler bir optional array olduğu için güvenli bir şekilde kontrol ediyoruz.
                budget.kategoriler?.contains(where: { $0.id == categoryID }) ?? false
            }
            
            guard !relevantBudgets.isEmpty else { return }
            
            // 3. ADIM: Bu ayki TÜM gider işlemlerini TEK BİR BASİT SORGUDAYLA çek.
            let calendar = Calendar.current
            guard let monthInterval = calendar.dateInterval(of: .month, for: Date()) else { return }
            
            let expenseTypeRaw = IslemTuru.gider.rawValue
            let expenseDescriptor = FetchDescriptor<Islem>(predicate: #Predicate {
                $0.turRawValue == expenseTypeRaw &&
                $0.tarih >= monthInterval.start &&
                $0.tarih < monthInterval.end
            })
            let allMonthlyExpenses = try context.fetch(expenseDescriptor)
            
            // 4. ADIM: Her bir bütçe için, hafızadaki verileri kullanarak hesaplama yap.
            for budget in relevantBudgets {
                guard let budgetCategoryIDs = budget.kategoriler?.map({ $0.id }) else { continue }
                let budgetCategorySet = Set(budgetCategoryIDs)
                
                // Bu bütçeyle ilgili harcamaları hafızada filtrele.
                let totalSpent = allMonthlyExpenses.filter {
                    guard let catID = $0.kategori?.id else { return false }
                    return budgetCategorySet.contains(catID)
                }.reduce(0) { $0 + $1.tutar }
                
                checkAndCreateNotification(for: budget, totalSpent: totalSpent, settings: settings, in: context)
            }
            
        } catch {
            Logger.log("BudgetService çalışırken hata oluştu: \(error.localizedDescription)", log: Logger.service, type: .error)
        }
    }
    
    private func checkAndCreateNotification(for budget: Butce, totalSpent: Double, settings: AppSettings, in context: ModelContext) {
        guard budget.limitTutar > 0 else { return }
        
        let spendingPercentage = totalSpent / budget.limitTutar
        
        if spendingPercentage >= 1.0 {
            let notification = Bildirim(tur: .butceLimitiAsildi, hedefID: budget.id, ilgiliIsim: budget.isim, tutar1: budget.limitTutar, tutar2: totalSpent - budget.limitTutar)
            context.insert(notification)
            
            // YENİ: Local notification ekle
            NotificationManager.shared.scheduleBudgetNotification(
                budgetName: budget.isim,
                percentage: spendingPercentage,
                notificationID: "budget-\(budget.id)-exceeded"
            )
        } else if spendingPercentage >= settings.budgetAlertThreshold {
            let notification = Bildirim(tur: .butceLimitiYaklasti, hedefID: budget.id, ilgiliIsim: budget.isim, tutar1: budget.limitTutar, tutar2: spendingPercentage)
            context.insert(notification)
            
            // YENİ: Local notification ekle
            NotificationManager.shared.scheduleBudgetNotification(
                budgetName: budget.isim,
                percentage: spendingPercentage,
                notificationID: "budget-\(budget.id)-threshold"
            )
        }
    }
}
