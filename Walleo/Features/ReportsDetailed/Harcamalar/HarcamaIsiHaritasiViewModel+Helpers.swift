// >> YENİ DOSYA: Features/ReportsDetailed/HarcamaIsiHaritasiViewModel+Helpers.swift

import SwiftUI
import SwiftData

extension HarcamaIsiHaritasiViewModel {
    
    // Zaman dilimlerini oluştur
    func createTimeSlots(gunSayisi: Int, islemler: [Islem]) -> [ZamanDilimiVerisi] {
        var slots: [ZamanDilimiVerisi] = []
        let calendar = Calendar.current
        
        switch gunSayisi {
        case 1:
            // Saatlik dilimler
            for hour in 0..<24 {
                let hourDate = calendar.date(
                    bySettingHour: hour,
                    minute: 0,
                    second: 0,
                    of: baslangicTarihi
                )!
                
                let hourTransactions = islemler.filter { islem in
                    calendar.component(.hour, from: islem.tarih) == hour
                }
                
                let slot = ZamanDilimiVerisi(
                    tarih: hourDate,
                    periyot: .saat(hourDate),
                    toplamTutar: hourTransactions.reduce(0) { $0 + $1.tutar },
                    islemSayisi: hourTransactions.count,
                    kategoriBazliTutar: calculateCategoryBreakdown(hourTransactions)
                )
                slots.append(slot)
            }
            
        case 2...35:
            // Günlük dilimler
            var currentDate = baslangicTarihi
            while currentDate <= bitisTarihi {
                let dayStart = calendar.startOfDay(for: currentDate)
                let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
                
                let dayTransactions = islemler.filter { islem in
                    islem.tarih >= dayStart && islem.tarih < dayEnd
                }
                
                let slot = ZamanDilimiVerisi(
                    tarih: dayStart,
                    periyot: .gun(dayStart),
                    toplamTutar: dayTransactions.reduce(0) { $0 + $1.tutar },
                    islemSayisi: dayTransactions.count,
                    kategoriBazliTutar: calculateCategoryBreakdown(dayTransactions)
                )
                slots.append(slot)
                
                currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
            }
            
        case 36...90:
            // Haftalık dilimler
            var weekStart = calendar.dateInterval(of: .weekOfYear, for: baslangicTarihi)!.start
            while weekStart <= bitisTarihi {
                let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart)!
                
                let weekTransactions = islemler.filter { islem in
                    islem.tarih >= weekStart && islem.tarih <= weekEnd
                }
                
                let slot = ZamanDilimiVerisi(
                    tarih: weekStart,
                    periyot: .hafta(weekStart, weekEnd),
                    toplamTutar: weekTransactions.reduce(0) { $0 + $1.tutar },
                    islemSayisi: weekTransactions.count,
                    kategoriBazliTutar: calculateCategoryBreakdown(weekTransactions)
                )
                slots.append(slot)
                
                weekStart = calendar.date(byAdding: .weekOfYear, value: 1, to: weekStart)!
            }
            
        default:
            // Aylık dilimler
            var monthStart = calendar.dateInterval(of: .month, for: baslangicTarihi)!.start
            while monthStart <= bitisTarihi {
                let monthEnd = calendar.dateInterval(of: .month, for: monthStart)!.end
                
                let monthTransactions = islemler.filter { islem in
                    islem.tarih >= monthStart && islem.tarih < monthEnd
                }
                
                let components = calendar.dateComponents([.month, .year], from: monthStart)
                let slot = ZamanDilimiVerisi(
                    tarih: monthStart,
                    periyot: .ay(components.month!, components.year!),
                    toplamTutar: monthTransactions.reduce(0) { $0 + $1.tutar },
                    islemSayisi: monthTransactions.count,
                    kategoriBazliTutar: calculateCategoryBreakdown(monthTransactions)
                )
                slots.append(slot)
                
                monthStart = calendar.date(byAdding: .month, value: 1, to: monthStart)!
            }
        }
        
        // Normalize yoğunlukları hesapla
        let maxAmount = slots.map { $0.toplamTutar }.max() ?? 1.0
        for i in 0..<slots.count {
            slots[i].normalizeEdilmisYogunluk = slots[i].toplamTutar / maxAmount
        }
        
        return slots
    }
    
    // Saatlik dağılımı hesapla
    func calculateHourlyDistribution(islemler: [Islem]) -> [SaatlikDagilimVerisi] {
        var hourlyData: [Int: (tutar: Double, sayi: Int)] = [:]
        let calendar = Calendar.current
        
        for islem in islemler {
            let hour = calendar.component(.hour, from: islem.tarih)
            hourlyData[hour, default: (0, 0)].tutar += islem.tutar
            hourlyData[hour, default: (0, 0)].sayi += 1
        }
        
        let toplamTutar = islemler.reduce(0) { $0 + $1.tutar }
        
        return (0..<24).map { hour in
            let data = hourlyData[hour] ?? (0, 0)
            return SaatlikDagilimVerisi(
                saat: hour,
                toplamTutar: data.tutar,
                islemSayisi: data.sayi,
                yuzde: toplamTutar > 0 ? (data.tutar / toplamTutar) * 100 : 0
            )
        }
    }
    
    // Karşılaştırma verilerini oluştur
    func createComparisonData(gunSayisi: Int, islemler: [Islem]) -> [HarcamaKarsilastirmaVerisi] {
        switch gunSayisi {
        case 1:
            return createHourlyPeriodComparison(islemler: islemler)
        case 2...6:
            return createDailyComparison(islemler: islemler)
        case 7...13:
            return createWeekdayWeekendComparison(islemler: islemler)
        case 14...60:
            return createWeeklyComparison(islemler: islemler)
        default:
            return createMonthlyComparison(islemler: islemler)
        }
    }
    
    // Kategori dağılımını hesapla
    private func calculateCategoryBreakdown(_ transactions: [Islem]) -> [UUID: Double] {
        var breakdown: [UUID: Double] = [:]
        for transaction in transactions {
            if let categoryID = transaction.kategori?.id {
                breakdown[categoryID, default: 0] += transaction.tutar
            }
        }
        return breakdown
    }
    
    // İçgörüleri oluştur
    func generateInsights(islemler: [Islem], gunSayisi: Int) -> [HarcamaIcgorusu] {
        var insights: [HarcamaIcgorusu] = []
        
        // En yoğun gün
        if let busiestDay = findBusiestDay(islemler: islemler) {
            insights.append(HarcamaIcgorusu(
                ikon: "📊",
                mesajKey: "reports.heatmap.insight.busiest_day",
                parametreler: ["date": busiestDay],
                oncelik: 1
            ))
        }
        
        // En aktif saat
        if let busiestHour = findBusiestHour(islemler: islemler) {
            insights.append(HarcamaIcgorusu(
                ikon: "⏰",
                mesajKey: "reports.heatmap.insight.busiest_hour",
                parametreler: ["hour": busiestHour],
                oncelik: 2
            ))
        }
        
        // Hafta sonu karşılaştırması
        if gunSayisi >= 7 {
            let weekendPercentage = calculateWeekendSpendingPercentage(islemler: islemler)
            if weekendPercentage > 0 {
                insights.append(HarcamaIcgorusu(
                    ikon: "📈",
                    mesajKey: "reports.heatmap.insight.weekend_comparison",
                    parametreler: ["percentage": Int(weekendPercentage)],
                    oncelik: 3
                ))
            }
        }
        
        return insights.sorted { $0.oncelik < $1.oncelik }
    }
}
