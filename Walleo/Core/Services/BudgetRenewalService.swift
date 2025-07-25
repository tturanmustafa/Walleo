import SwiftUI
import SwiftData
import UserNotifications

@MainActor
class BudgetRenewalService {

    // MARK: - Properties
    
    private let modelContext: ModelContext
    private let appSettings = AppSettings()
    
    // Performans için cache
    private var devirCache: [UUID: Double] = [:]
    private let maxMonthsToProcess = 12 // Maksimum geriye gidilecek ay sayısı

    // MARK: - Init
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Main Function
    
    /// Bütçe yenileme ve bildirim gönderme işlemlerini başlatan ana fonksiyon.
    func runDailyChecks() async {
        Logger.log("Günlük bütçe kontrolü başlatıldı.", log: Logger.service)

        // Cache'i temizle
        devirCache.removeAll()

        // 1. Otomatik yenilemesi aktif olan tüm bütçeleri çek.
        let descriptor = FetchDescriptor<Butce>(
            predicate: #Predicate { $0.otomatikYenile == true }
        )
        
        guard let aktifYenilemeliButceler = try? modelContext.fetch(descriptor) else {
            Logger.log("Otomatik yenilenecek bütçe bulunamadı", log: Logger.service)
            return
        }

        // 2. Verimlilik için bütçeleri ana ID'lerine (zincirlerine) göre grupla.
        let butceZincirleri = Dictionary(grouping: aktifYenilemeliButceler, by: {
            $0.anaButceID ?? $0.id
        })

        Logger.log("\(butceZincirleri.count) bütçe zinciri bulundu", log: Logger.service)

        // 3. Her bir bütçe zinciri için telafi kontrolü yap.
        for (anaID, zincir) in butceZincirleri {
            // Zincirdeki en son tarihli (en güncel) bütçeyi bul.
            guard let sonButce = zincir.max(by: { $0.periyot < $1.periyot }) else { continue }
            
            // Infinite loop koruması ile eksik ayları işle
            var mevcutSonButce = sonButce
            var iterationCount = 0
            
            while let birSonrakiPeriyot = getNextPeriod(for: mevcutSonButce.periyot),
                  birSonrakiPeriyot <= Date(),
                  iterationCount < maxMonthsToProcess {
                
                iterationCount += 1
                Logger.log("[\(iterationCount)/\(maxMonthsToProcess)] '\(mevcutSonButce.isim)' için kayıp ay (\(formatDate(birSonrakiPeriyot))) yenileniyor...", log: Logger.service)
                
                // Eksik ay için yeni bütçeyi oluştur
                mevcutSonButce = await renewSingleBudget(from: mevcutSonButce, to: birSonrakiPeriyot)
                
                // Her 3 bütçede bir save yap (performans için)
                if iterationCount % 3 == 0 {
                    do {
                        try modelContext.save()
                    } catch {
                        Logger.log("Ara kaydetme hatası: \(error)", log: Logger.service, type: .error)
                    }
                }
            }
            
            if iterationCount >= maxMonthsToProcess {
                Logger.log("UYARI: '\(mevcutSonButce.isim)' için maksimum yenileme sayısına ulaşıldı!", log: Logger.service, type: .error)
            }
        }
        
        // Final save
        do {
            try modelContext.save()
            Logger.log("Bütçe yenileme işlemi tamamlandı", log: Logger.service)
        } catch {
            Logger.log("Final kaydetme hatası: \(error)", log: Logger.service, type: .error)
        }
        
        // 4. Ön onay bildirimlerini gönderme mantığı
        let takvim = Calendar.current
        let bugun = takvim.startOfDay(for: Date())
        if isOneDayBeforeEndOfMonth(date: bugun, calendar: takvim) {
            await sendPreRenewalNotifications(for: bugun)
        }
    }
    
    private func checkDailyNotifications() async {
        // Kredi taksitlerini kontrol et
        NotificationManager.shared.checkLoanInstallments()
        
        // Kredi kartı ödeme tarihlerini kontrol et
        NotificationManager.shared.checkCreditCardDueDates()
        
        // Badge sayısını güncelle
        NotificationManager.shared.updateBadgeCount()
    }

    // MARK: - Yenileme Fonksiyonları

    /// Tek bir bütçeyi, belirtilen yeni periyot için yeniler ve oluşturulan yeni bütçeyi döndürür.
    private func renewSingleBudget(from previousBudget: Butce, to newPeriod: Date) async -> Butce {
        var buAykiDevir: Double = 0
        
        if previousBudget.devredenBakiyeEtkin {
            buAykiDevir = await calculateRolloverAmount(for: previousBudget)
            Logger.log("'\(previousBudget.isim)' için devir tutarı: \(buAykiDevir)", log: Logger.service)
        }
        
        var guncelDevirGecmisi = previousBudget.devirGecmisiSozlugu
        if buAykiDevir > 0 {
            let ayAdi = monthYearString(from: previousBudget.periyot, localeIdentifier: appSettings.languageCode)
            guncelDevirGecmisi[ayAdi, default: 0] += buAykiDevir
        }
        
        let toplamDevredenTutar = guncelDevirGecmisi.values.reduce(0, +)
        
        let yeniButce = Butce(
            isim: previousBudget.isim,
            limitTutar: previousBudget.limitTutar,
            periyot: newPeriod,
            otomatikYenile: previousBudget.otomatikYenile,
            devredenBakiyeEtkin: previousBudget.devredenBakiyeEtkin,
            kategoriler: previousBudget.kategoriler ?? [],
            anaButceID: previousBudget.anaButceID ?? previousBudget.id,
            devredenGelenTutar: toplamDevredenTutar
        )
        
        yeniButce.devirGecmisiSozlugu = guncelDevirGecmisi
        modelContext.insert(yeniButce)
        
        Logger.log("Yeni bütçe oluşturuldu: '\(yeniButce.isim)' - Periyot: \(formatDate(newPeriod))", log: Logger.service)
        
        return yeniButce
    }

    /// Bir tarihin bir sonraki ayının başlangıcını döndürür.
    private func getNextPeriod(for date: Date) -> Date? {
        let calendar = Calendar.current
        guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: date) else { return nil }
        
        // Ayın ilk gününe normalize et
        let components = calendar.dateComponents([.year, .month], from: nextMonth)
        return calendar.date(from: components)
    }

    /// Bir bütçenin devreden tutarını hesaplar (GÜVENLİ VERSİYON).
    private func calculateRolloverAmount(for budget: Butce) async -> Double {
        // Cache kontrolü
        if let cached = devirCache[budget.id] {
            return cached
        }
        
        guard let ayAraligi = Calendar.current.dateInterval(of: .month, for: budget.periyot),
              let kategoriIDleri = budget.kategoriler?.map({ $0.id }),
              !kategoriIDleri.isEmpty else {
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
            let result = max(0, kalanBakiye)
            
            // Cache'e kaydet
            devirCache[budget.id] = result
            
            return result
            
        } catch {
            Logger.log("Devir hesaplaması için harcamalar çekilirken hata: \(error)", log: Logger.service, type: .error)
            return 0
        }
    }

    // MARK: - Notification Logic
    
    /// Ay sonundan bir gün önce yenilenecek bütçeler için bildirim oluşturur.
    private func sendPreRenewalNotifications(for date: Date) async {
        guard let ayAraligi = Calendar.current.dateInterval(of: .month, for: date) else { return }
        
        let predicate = #Predicate<Butce> { butce in
            butce.periyot >= ayAraligi.start &&
            butce.periyot < ayAraligi.end &&
            butce.otomatikYenile == true
        }
        let descriptor = FetchDescriptor(predicate: predicate)

        do {
            let yenilenecekButceler = try modelContext.fetch(descriptor)
            guard !yenilenecekButceler.isEmpty else { return }
            
            Logger.log("\(yenilenecekButceler.count) bütçe için ön bildirim oluşturuluyor", log: Logger.service)
            
            for butce in yenilenecekButceler {
                var devredenTutar: Double = 0
                if butce.devredenBakiyeEtkin {
                    devredenTutar = await calculateRolloverAmount(for: butce)
                }
                
                let bildirim = Bildirim(
                    tur: .butceYenilemeOncesi,
                    hedefID: butce.id,
                    ilgiliIsim: butce.isim,
                    tutar1: devredenTutar
                )
                modelContext.insert(bildirim)
            }
            
            try modelContext.save()
            
        } catch {
            Logger.log("Ön yenileme bildirimleri oluşturulurken hata: \(error)", log: Logger.service, type: .error)
        }
    }

    /// Ayın ilk günü, yenilenen bütçeler için bir özet bildirimi oluşturur.
    private func sendRenewalSummaryNotification(for month: Date, yenilenenSayi: Int) async {
        let ayAdi = monthYearString(from: month, localeIdentifier: appSettings.languageCode)
        
        let bildirim = Bildirim(
            tur: .butceYenilemeSonrasi,
            ilgiliIsim: ayAdi,
            tutar1: Double(yenilenenSayi)
        )
        modelContext.insert(bildirim)
        
        do {
            try modelContext.save()
            Logger.log("Yenileme özet bildirimi oluşturuldu: \(yenilenenSayi) bütçe yenilendi", log: Logger.service)
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
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
