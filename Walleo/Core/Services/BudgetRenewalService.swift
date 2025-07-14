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
        Logger.log("Günlük bütçe kontrolü başlatıldı.", log: Logger.service)

        // 1. Otomatik yenilemesi aktif olan tüm bütçeleri çek.
        let descriptor = FetchDescriptor<Butce>(predicate: #Predicate { $0.otomatikYenile == true })
        guard let aktifYenilemeliButceler = try? modelContext.fetch(descriptor) else { return }

        // 2. Verimlilik için bütçeleri ana ID'lerine (zincirlerine) göre grupla.
        // anaButceID'si olmayanlar (ilk oluşturulanlar) kendi ID'leri ile gruplanır.
        let butceZincirleri = Dictionary(grouping: aktifYenilemeliButceler, by: { $0.anaButceID ?? $0.id })

        // 3. Her bir bütçe zinciri için telafi kontrolü yap.
        for (_, zincir) in butceZincirleri {
            // Zincirdeki en son tarihli (en güncel) bütçeyi bul.
            guard let sonButce = zincir.max(by: { $0.periyot < $1.periyot }) else { continue }
            
            // Bu döngü, eksik olan tüm ayları yakalayana kadar çalışır.
            // Örneğin, kullanıcı uygulamayı 3 ay sonra açtıysa, 3 kez çalışır.
            var mevcutSonButce = sonButce
            while let birSonrakiPeriyot = getNextPeriod(for: mevcutSonButce.periyot), birSonrakiPeriyot <= Date() {
                Logger.log("'\(mevcutSonButce.isim)' için kayıp ay (\(birSonrakiPeriyot)) bulundu, yenileniyor...", log: Logger.service)
                // Eksik ay için yeni bütçeyi oluştur ve bir sonraki döngü için en son bütçe olarak ata.
                mevcutSonButce = await renewSingleBudget(from: mevcutSonButce, to: birSonrakiPeriyot)
            }
        }
        
        // 4. Ön onay bildirimlerini gönderme mantığı (bu ayrı çalışabilir).
        let takvim = Calendar.current
        let bugun = takvim.startOfDay(for: Date())
        if isOneDayBeforeEndOfMonth(date: bugun, calendar: takvim) {
            await sendPreRenewalNotifications(for: bugun)
        }
    }

    // --- YENİ EKLENDİ: İki yeni yardımcı fonksiyon ---

    /// Tek bir bütçeyi, belirtilen yeni periyot için yeniler ve oluşturulan yeni bütçeyi döndürür.
    private func renewSingleBudget(from previousBudget: Butce, to newPeriod: Date) async -> Butce {
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
        
        let yeniButce = Butce(
            isim: previousBudget.isim,
            limitTutar: previousBudget.limitTutar,
            periyot: newPeriod,
            otomatikYenile: previousBudget.otomatikYenile,
            devredenBakiyeEtkin: previousBudget.devredenBakiyeEtkin,
            kategoriler: previousBudget.kategoriler ?? [],
            anaButceID: previousBudget.id,
            devredenGelenTutar: toplamDevredenTutar
        )
        
        yeniButce.devirGecmisiSozlugu = guncelDevirGecmisi
        modelContext.insert(yeniButce)
        
        try? modelContext.save()
        
        // Özet bildirimi için bu bilgiyi kullanabiliriz.
        // Şimdilik sadece yeni bütçeyi döndürüyoruz.
        return yeniButce
    }

    /// Bir tarihin bir sonraki ayının başlangıcını döndürür.
    private func getNextPeriod(for date: Date) -> Date? {
        Calendar.current.date(byAdding: .month, value: 1, to: date)
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
