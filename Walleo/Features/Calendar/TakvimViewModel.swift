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
    
    var calendarDays: [CalendarDay] = []
    var aylikToplamGelir: Double = 0.0
    var aylikToplamGider: Double = 0.0
    var aylikNetFark: Double { aylikToplamGelir - aylikToplamGider }
    
    // YENİ: Hangi tarihi güncelleyeceğimizi bilmek için bu değişkeni ekliyoruz.
    private var sonGuncellenenTarih: Date = Date()
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDataChange), // Bu fonksiyon artık iş yapacak
            name: .transactionsDidChange,
            object: nil
        )
    }
    
    // YENİ: Bildirim geldiğinde bu fonksiyon tetiklenecek
    @objc private func handleDataChange() {
        // En son hangi ayda kaldıysak, o ay için takvimi yeniden oluştur.
        generateCalendar(forDate: sonGuncellenenTarih)
    }

    func generateCalendar(forDate date: Date) {
        // Hangi tarihi güncellediğimizi kaydediyoruz.
        self.sonGuncellenenTarih = date
        
        var calendar = Calendar.current
        calendar.firstWeekday = 2 // Pazartesi
        
        guard let monthInterval = calendar.dateInterval(of: .month, for: date),
              let firstDayOfMonth = monthInterval.start.firstDayOfWeek(using: calendar) else { return }
        
        var days: [CalendarDay] = []
        for i in 0..<42 {
            if let day = calendar.date(byAdding: .day, value: i, to: firstDayOfMonth) {
                let isCurrent = calendar.isDate(day, equalTo: date, toGranularity: .month)
                // Her gün için net tutarı sıfırlayarak başlıyoruz.
                days.append(CalendarDay(date: day, isCurrentMonth: isCurrent, netAmount: 0.0))
            }
        }
        
        self.calendarDays = days
        fetchAndAssignTransactions(for: monthInterval)
    }
    
    private func fetchAndAssignTransactions(for interval: DateInterval) {
        let descriptor = FetchDescriptor<Islem>(
            predicate: #Predicate { $0.tarih >= interval.start && $0.tarih < interval.end }
        )
        
        do {
            let transactions = try modelContext.fetch(descriptor)
            
            self.aylikToplamGelir = transactions.filter { $0.tur == .gelir }.reduce(0) { $0 + $1.tutar }
            self.aylikToplamGider = transactions.filter { $0.tur == .gider }.reduce(0) { $0 + $1.tutar }
            
            let groupedByDay = Dictionary(grouping: transactions) { transaction in
                Calendar.current.startOfDay(for: transaction.tarih)
            }
            
            for i in 0..<calendarDays.count {
                calendarDays[i].netAmount = 0 // Her döngüde sıfırla
                let dayDate = Calendar.current.startOfDay(for: calendarDays[i].date)
                if let transactionsForDay = groupedByDay[dayDate] {
                    let income = transactionsForDay.filter { $0.tur == .gelir }.reduce(0) { $0 + $1.tutar }
                    let expense = transactionsForDay.filter { $0.tur == .gider }.reduce(0) { $0 + $1.tutar }
                    calendarDays[i].netAmount = income - expense
                }
            }
        } catch {
            Logger.log("Takvim için işlem verisi çekilemedi: \(error.localizedDescription)", log: Logger.data, type: .error)
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
