// >> YENİ DOSYA: Features/ReportsDetailed/HarcamaIsiHaritasiViewModel+Insights.swift

import SwiftUI
import SwiftData

extension HarcamaIsiHaritasiViewModel {
    
    func findBusiestDay(islemler: [Islem]) -> String? {
        let calendar = Calendar.current
        var dailyTotals: [Date: Double] = [:]
        
        for islem in islemler {
            let day = calendar.startOfDay(for: islem.tarih)
            dailyTotals[day, default: 0] += islem.tutar
        }
        
        guard let (busiestDate, _) = dailyTotals.max(by: { $0.value < $1.value }) else {
            return nil
        }
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: appSettings.languageCode)
        formatter.dateFormat = "d MMMM"
        
        return formatter.string(from: busiestDate)
    }
    
    func findBusiestHour(islemler: [Islem]) -> String? {
        let calendar = Calendar.current
        var hourlyTotals: [Int: Double] = [:]
        
        for islem in islemler {
            let hour = calendar.component(.hour, from: islem.tarih)
            hourlyTotals[hour, default: 0] += islem.tutar
        }
        
        guard let (busiestHour, _) = hourlyTotals.max(by: { $0.value < $1.value }) else {
            return nil
        }
        
        return String(format: "%02d:00-%02d:00", busiestHour, (busiestHour + 1) % 24)
    }
    
    func calculateWeekendSpendingPercentage(islemler: [Islem]) -> Double {
        let calendar = Calendar.current
        
        let weekdayTotal = islemler
            .filter { !calendar.isDateInWeekend($0.tarih) }
            .reduce(0) { $0 + $1.tutar }
        
        let weekendTotal = islemler
            .filter { calendar.isDateInWeekend($0.tarih) }
            .reduce(0) { $0 + $1.tutar }
        
        guard weekdayTotal > 0 else { return 0 }
        
        let difference = ((weekendTotal - weekdayTotal) / weekdayTotal) * 100
        return difference
    }
    
    func findNoSpendingDays(gunSayisi: Int, islemler: [Islem]) -> Int {
        let calendar = Calendar.current
        var allDays = Set<Date>()
        var daysWithSpending = Set<Date>()
        
        // Tüm günleri oluştur
        var currentDate = baslangicTarihi
        while currentDate <= bitisTarihi {
            allDays.insert(calendar.startOfDay(for: currentDate))
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }
        
        // Harcama olan günleri işaretle
        for islem in islemler {
            daysWithSpending.insert(calendar.startOfDay(for: islem.tarih))
        }
        
        return allDays.count - daysWithSpending.count
    }
}
