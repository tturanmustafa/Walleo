// >> YENİ DOSYA: Features/ReportsDetailed/HarcamaIsiHaritasiViewModel+Comparisons.swift

import SwiftUI
import SwiftData

extension HarcamaIsiHaritasiViewModel {
    
    // Günün saatlik dilimlerini karşılaştır (Sabah/Öğle/Akşam/Gece)
    func createHourlyPeriodComparison(islemler: [Islem]) -> [HarcamaKarsilastirmaVerisi] {
        let periods = [
            (range: 6..<12, key: "reports.heatmap.morning", color: Color.orange),
            (range: 12..<18, key: "reports.heatmap.noon", color: Color.yellow),
            (range: 18..<24, key: "reports.heatmap.evening", color: Color.blue),
            (range: 0..<6, key: "reports.heatmap.night", color: Color.purple)
        ]
        
        let calendar = Calendar.current
        let toplamHarcama = islemler.reduce(0) { $0 + $1.tutar }
        
        return periods.map { period in
            let periodTransactions = islemler.filter { islem in
                let hour = calendar.component(.hour, from: islem.tarih)
                return period.range.contains(hour)
            }
            
            let periodTotal = periodTransactions.reduce(0) { $0 + $1.tutar }
            let percentage = toplamHarcama > 0 ? (periodTotal / toplamHarcama) * 100 : 0
            
            return HarcamaKarsilastirmaVerisi(  // <- Tip değişti
                etiket: NSLocalizedString(period.key, comment: ""),
                localizationKey: period.key,
                deger: periodTotal,
                yuzde: percentage,
                renk: period.color
            )
        }
    }
    
    // Günlük karşılaştırma
    func createDailyComparison(islemler: [Islem]) -> [HarcamaKarsilastirmaVerisi] {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: appSettings.languageCode)
        formatter.dateFormat = "E" // Kısa gün adı
        
        var dailyTotals: [Date: Double] = [:]
        
        for islem in islemler {
            let day = calendar.startOfDay(for: islem.tarih)
            dailyTotals[day, default: 0] += islem.tutar
        }
        
        let toplamHarcama = islemler.reduce(0) { $0 + $1.tutar }
        let sortedDays = dailyTotals.keys.sorted()
        
        return sortedDays.map { date in
            let total = dailyTotals[date] ?? 0
            let percentage = toplamHarcama > 0 ? (total / toplamHarcama) * 100 : 0
            
            return HarcamaKarsilastirmaVerisi(
                etiket: formatter.string(from: date),
                localizationKey: nil,
                deger: total,
                yuzde: percentage,
                renk: calendar.isDateInWeekend(date) ? .orange : .blue
            )
        }
    }
    
    // Hafta içi vs Hafta sonu karşılaştırması
    func createWeekdayWeekendComparison(islemler: [Islem]) -> [HarcamaKarsilastirmaVerisi] {
        let calendar = Calendar.current
        
        let weekdayTransactions = islemler.filter { !calendar.isDateInWeekend($0.tarih) }
        let weekendTransactions = islemler.filter { calendar.isDateInWeekend($0.tarih) }
        
        let weekdayTotal = weekdayTransactions.reduce(0) { $0 + $1.tutar }
        let weekendTotal = weekendTransactions.reduce(0) { $0 + $1.tutar }
        
        let weekdayDays = Set(weekdayTransactions.map { calendar.startOfDay(for: $0.tarih) }).count
        let weekendDays = Set(weekendTransactions.map { calendar.startOfDay(for: $0.tarih) }).count
        
        let weekdayAverage = weekdayDays > 0 ? weekdayTotal / Double(weekdayDays) : 0
        let weekendAverage = weekendDays > 0 ? weekendTotal / Double(weekendDays) : 0
        
        return [
            HarcamaKarsilastirmaVerisi(
                etiket: NSLocalizedString("reports.heatmap.weekday", comment: ""),
                localizationKey: "reports.heatmap.weekday",
                deger: weekdayAverage,
                yuzde: 0,
                renk: .blue
            ),
            HarcamaKarsilastirmaVerisi(
                etiket: NSLocalizedString("reports.heatmap.weekend", comment: ""),
                localizationKey: "reports.heatmap.weekend",
                deger: weekendAverage,
                yuzde: 0,
                renk: .orange
            )
        ]
    }
    
    // Haftalık karşılaştırma
    func createWeeklyComparison(islemler: [Islem]) -> [HarcamaKarsilastirmaVerisi] {
        let calendar = Calendar.current
        var weeklyTotals: [Date: Double] = [:]
        
        for islem in islemler {
            let weekStart = calendar.dateInterval(of: .weekOfYear, for: islem.tarih)!.start
            weeklyTotals[weekStart, default: 0] += islem.tutar
        }
        
        let sortedWeeks = weeklyTotals.keys.sorted()
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: appSettings.languageCode)
        formatter.dateFormat = "d MMM"
        
        return sortedWeeks.enumerated().map { index, weekStart in
            let total = weeklyTotals[weekStart] ?? 0
            let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart)!
            
            return HarcamaKarsilastirmaVerisi(
                etiket: "\(index + 1). Hafta",
                localizationKey: nil,
                deger: total,
                yuzde: 0,
                renk: Color.blue.opacity(0.8 - Double(index) * 0.1)
            )
        }
    }
    
    // Aylık karşılaştırma
    func createMonthlyComparison(islemler: [Islem]) -> [HarcamaKarsilastirmaVerisi] {
        let calendar = Calendar.current
        var monthlyTotals: [Date: Double] = [:]
        
        for islem in islemler {
            let monthStart = calendar.dateInterval(of: .month, for: islem.tarih)!.start
            monthlyTotals[monthStart, default: 0] += islem.tutar
        }
        
        let sortedMonths = monthlyTotals.keys.sorted()
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: appSettings.languageCode)
        formatter.dateFormat = "MMM"
        
        return sortedMonths.map { monthStart in
            let total = monthlyTotals[monthStart] ?? 0
            
            return HarcamaKarsilastirmaVerisi(
                etiket: formatter.string(from: monthStart),
                localizationKey: nil,
                deger: total,
                yuzde: 0,
                renk: .blue
            )
        }
    }
}
