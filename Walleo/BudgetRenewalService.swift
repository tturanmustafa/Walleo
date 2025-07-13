import SwiftUI
import SwiftData
import UserNotifications

@MainActor
class BudgetRenewalService {

    // MARK: - Properties
    
    private let modelContext: ModelContext
    private let appSettings = AppSettings() // Lokalizasyon ve para birimi için

    // MARK: - Init
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Main Function
    
    /// Bütçe yenileme ve bildirim gönderme işlemlerini başlatan ana fonksiyon.
    /// Bu fonksiyonun, uygulamanın arka plan görevi tarafından (örn: her günün başında) çağrılması hedeflenir.
    func runDailyChecks() async {
        let takvim = Calendar.current
        let bugun = takvim.startOfDay(for: Date())

        // 1. Ayın sonundan bir gün önce miyiz? Ön onay bildirimleri için kontrol.
        if isOneDayBeforeEndOfMonth(date: bugun, calendar: takvim) {
            await sendPreRenewalNotifications(for: bugun)
        }

        // 2. Ayın ilk günü müyüz? Yenileme işlemleri ve özet bildirimi için kontrol.
        if takvim.component(.day, from: bugun) == 1 {
            guard let oncekiAyinIlkGunu = takvim.date(byAdding: .month, value: -1, to: bugun) else { return }
            let yenilenenButceSayisi = await renewBudgets(for: oncekiAyinIlkGunu)
            
            // Sadece bütçe yenilendiyse özet bildirimi gönder
            if yenilenenButceSayisi > 0 {
                await sendRenewalSummaryNotification(for: bugun, yenilenenSayi: yenilenenButceSayisi)
            }
        }
    }

    // MARK: - Budget Renewal Logic
    
    /// Belirtilen ayın bütçelerini bir sonraki ay için yeniler ve yenilenen bütçe sayısını döndürür.
    private func renewBudgets(for month: Date) async -> Int {
        guard let ayAraligi = Calendar.current.dateInterval(of: .month, for: month) else { return 0 }

        let predicate = #Predicate<Butce> { butce in
            butce.periyot >= ayAraligi.start &&
            butce.periyot < ayAraligi.end &&
            butce.otomatikYenile == true
        }
        let descriptor = FetchDescriptor(predicate: predicate)

        do {
            let yenilenecekButceler = try modelContext.fetch(descriptor)
            guard !yenilenecekButceler.isEmpty else { return 0 }
            
            Logger.log("\(yenilenecekButceler.count) adet bütçe yenileme için bulundu.", log: Logger.service)

            for butce in yenilenecekButceler {
                await createNextMonthBudget(from: butce)
            }
            
            try modelContext.save()
            return yenilenecekButceler.count
            
        } catch {
            Logger.log("Yenilenecek bütçeler çekilirken hata: \(error)", log: Logger.service, type: .error)
            return 0
        }
    }

    /// Verilen bir bütçeden yola çıkarak bir sonraki ay için yeni bir bütçe oluşturur.
    private func createNextMonthBudget(from previousBudget: Butce) async {
        var buAykiDevir: Double = 0
        if previousBudget.devredenBakiyeEtkin {
            buAykiDevir = await calculateRolloverAmount(for: previousBudget)
        }
        
        var guncelDevirGecmisi = previousBudget.devirGecmisiSozlugu
        if buAykiDevir > 0 {
            let ayAdi = monthYearString(from: previousBudget.periyot, localeIdentifier: appSettings.languageCode)
            guncelDevirGecmisi[ayAdi, default: 0] += buAykiDevir
        }
        
        let toplamDevredenTutar = guncelDevirGecmisi.values.reduce(0, +)
        
        guard let yeniPeriyot = Calendar.current.date(byAdding: .month, value: 1, to: previousBudget.periyot) else { return }
        
        let yeniButce = Butce(
            isim: previousBudget.isim,
            limitTutar: previousBudget.limitTutar, // Ana limit sabit kalır
            periyot: yeniPeriyot,
            otomatikYenile: previousBudget.otomatikYenile,
            devredenBakiyeEtkin: previousBudget.devredenBakiyeEtkin,
            kategoriler: previousBudget.kategoriler ?? [],
            anaButceID: previousBudget.id,
            devredenGelenTutar: toplamDevredenTutar
        )
        
        yeniButce.devirGecmisiSozlugu = guncelDevirGecmisi
        modelContext.insert(yeniButce)
    }

    /// Bir bütçenin devreden tutarını hesaplar (GÜVENLİ VERSİYON).
    private func calculateRolloverAmount(for budget: Butce) async -> Double {
        guard let ayAraligi = Calendar.current.dateInterval(of: .month, for: budget.periyot),
              let kategoriIDleri = budget.kategoriler?.map({ $0.id }), !kategoriIDleri.isEmpty else {
            return 0
        }

        let kategoriIDSet = Set(kategoriIDleri)
        
        do {
            let giderTuruRaw = IslemTuru.gider.rawValue
            let descriptor = FetchDescriptor<Islem>(
                predicate: #Predicate { islem in
                    islem.tarih >= ayAraligi.start &&
                    islem.tarih < ayAraligi.end &&
                    islem.turRawValue == giderTuruRaw
                }
            )
            let tumDonemGiderleri = try modelContext.fetch(descriptor)
            
            let ilgiliIslemler = tumDonemGiderleri.filter { islem in
                guard let kategoriID = islem.kategori?.id else { return false }
                return kategoriIDSet.contains(kategoriID)
            }
            
            let toplamHarcama = ilgiliIslemler.reduce(0) { $0 + $1.tutar }
            let kalanBakiye = budget.limitTutar - toplamHarcama
            
            return max(0, kalanBakiye)
        } catch {
            Logger.log("Devir hesaplaması için harcamalar çekilirken hata: \(error)", log: Logger.service, type: .error)
            return 0
        }
    }

    // MARK: - Notification Logic
    
    /// Ay sonundan bir gün önce yenilenecek bütçeler için bildirim oluşturur.
    private func sendPreRenewalNotifications(for date: Date) async {
        // ... (fonksiyonun başındaki veri çekme mantığı aynı)
        guard let ayAraligi = Calendar.current.dateInterval(of: .month, for: date) else { return }
        let predicate = #Predicate<Butce> { butce in
            butce.periyot >= ayAraligi.start && butce.periyot < ayAraligi.end && butce.otomatikYenile == true
        }
        let descriptor = FetchDescriptor(predicate: predicate)

        do {
            let yenilenecekButceler = try modelContext.fetch(descriptor)
            guard !yenilenecekButceler.isEmpty else { return }
            
            for butce in yenilenecekButceler {
                var devredenTutar: Double = 0
                if butce.devredenBakiyeEtkin {
                    devredenTutar = await calculateRolloverAmount(for: butce)
                }
                
                // --- DÜZELTME BAŞLANGICI: DOĞRU PARAMETRE SIRASI ---
                let bildirim = Bildirim(
                    tur: .butceYenilemeOncesi,
                    hedefID: butce.id,                  // hedefID önce
                    ilgiliIsim: butce.isim,             // ilgiliIsim sonra
                    tutar1: devredenTutar
                )
                modelContext.insert(bildirim)
                // --- DÜZELTME SONU ---
            }
            
            try modelContext.save()
            
        } catch {
            Logger.log("Ön yenileme bildirimleri oluşturulurken hata: \(error)", log: Logger.service, type: .error)
        }
    }

    /// Ayın ilk günü, yenilenen bütçeler için bir özet bildirimi oluşturur.
    private func sendRenewalSummaryNotification(for month: Date, yenilenenSayi: Int) async {
        // Ay adını lokalize et
        let ayAdi = monthYearString(from: month, localeIdentifier: appSettings.languageCode)
        
        // --- DÜZELTME BAŞLANGICI ---
        // Bildirim nesnesi, doğru init metodu kullanılarak oluşturuluyor.
        let bildirim = Bildirim(
            tur: .butceYenilemeSonrasi,
            ilgiliIsim: ayAdi,
            tutar1: Double(yenilenenSayi)
        )
        modelContext.insert(bildirim)
        // --- DÜZELTME SONU ---
        
        do {
            try modelContext.save()
        } catch {
            Logger.log("Yenileme özet bildirimi kaydedilirken hata: \(error)", log: Logger.service, type: .error)
        }
    }
    
    // MARK: - Helper Functions

    /// Verilen tarihin, ayın bitimine bir gün kalıp kalmadığını kontrol eder.
    private func isOneDayBeforeEndOfMonth(date: Date, calendar: Calendar) -> Bool {
        guard let birSonrakiGun = calendar.date(byAdding: .day, value: 1, to: date) else { return false }
        return calendar.component(.month, from: date) != calendar.component(.month, from: birSonrakiGun)
    }
}
