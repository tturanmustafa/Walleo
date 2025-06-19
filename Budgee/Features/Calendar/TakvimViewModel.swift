import SwiftUI
import SwiftData

// Takvimdeki bir günü temsil eden veri yapısı
struct CalendarDay: Identifiable {
    let id = UUID()
    let date: Date
    var dayNumber: String {
        let components = Calendar.current.dateComponents([.day], from: date)
        return String(components.day ?? 0)
    }
    var isCurrentMonth: Bool
    var netAmount: Double = 0.0
}

@MainActor
@Observable
class TakvimViewModel {
    var modelContext: ModelContext
    
    // currentDate değişkeni buradan kaldırıldı.
    
    var calendarDays: [CalendarDay] = []
    var aylikToplamGelir: Double = 0.0
    var aylikToplamGider: Double = 0.0
    var aylikNetFark: Double { aylikToplamGelir - aylikToplamGider }
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        // Başlangıçta boş bir takvim oluşturabiliriz veya mevcut ay için.
        generateCalendar(forDate: Date())
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDataChange),
            name: .transactionsDidChange,
            object: nil
        )
    }
    
    @objc private func handleDataChange() {
        // Bu fonksiyon artık doğrudan generateCalendar çağırmak yerine
        // View'ın yeniden tetiklenmesini bekleyecek. Veya son tarihi saklayıp onu çağırabilir.
        // Şimdilik en temizi, View'ın bunu yönetmesi.
    }

    // GÜNCELLEME: Fonksiyon artık dışarıdan bir tarih alıyor.
    func generateCalendar(forDate date: Date) {
        var calendar = Calendar.current
        calendar.firstWeekday = 2 // Pazartesi
        
        guard let monthInterval = calendar.dateInterval(of: .month, for: date),
              let firstDayOfMonth = monthInterval.start.firstDayOfWeek(using: calendar) else { return }
        
        var days: [CalendarDay] = []
        for i in 0..<42 {
            if let day = calendar.date(byAdding: .day, value: i, to: firstDayOfMonth) {
                let isCurrent = calendar.isDate(day, equalTo: date, toGranularity: .month)
                days.append(CalendarDay(date: day, isCurrentMonth: isCurrent))
            }
        }
        
        self.calendarDays = days
        fetchAndAssignTransactions(for: monthInterval)
    }
    
    private func fetchAndAssignTransactions(for interval: DateInterval) {
        let descriptor = FetchDescriptor<Islem>(
            predicate: #Predicate { $0.tarih >= interval.start && $0.tarih < interval.end }
        )
        
        guard let transactions = try? modelContext.fetch(descriptor) else { return }
        
        self.aylikToplamGelir = transactions.filter { $0.tur == .gelir }.reduce(0) { $0 + $1.tutar }
        self.aylikToplamGider = transactions.filter { $0.tur == .gider }.reduce(0) { $0 + $1.tutar }
        
        let groupedByDay = Dictionary(grouping: transactions) { transaction in
            Calendar.current.startOfDay(for: transaction.tarih)
        }
        
        for i in 0..<calendarDays.count {
            let dayDate = Calendar.current.startOfDay(for: calendarDays[i].date)
            if let transactionsForDay = groupedByDay[dayDate] {
                let income = transactionsForDay.filter { $0.tur == .gelir }.reduce(0) { $0 + $1.tutar }
                let expense = transactionsForDay.filter { $0.tur == .gider }.reduce(0) { $0 + $1.tutar }
                calendarDays[i].netAmount = income - expense
            }
        }
    }
}

fileprivate extension Date {
    func firstDayOfWeek(using calendar: Calendar) -> Date? {
        var calendar = calendar
        calendar.firstWeekday = 2
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self)
        return calendar.date(from: components)
    }
}
