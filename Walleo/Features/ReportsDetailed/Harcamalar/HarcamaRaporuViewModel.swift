// Features/ReportsDetailed/Harcamalar/HarcamaRaporuViewModel.swift

import SwiftUI
import SwiftData

@MainActor
@Observable
class HarcamaRaporuViewModel {
    private var modelContext: ModelContext
    var baslangicTarihi: Date
    var bitisTarihi: Date
    private var appSettings: AppSettings  // ← YENİ SATIR

    // UI veriler - TÜM TİPLER GÜNCELLENDİ
    var genelOzet = HarcamaGenelOzet()
    var topKategoriler: [HarcamaKategoriOzet] = []
    var kategoriDetaylari: [HarcamaKategoriDetay] = []
    var gunlukHarcamalar: [HarcamaGunlukVeri] = []
    var haftalikOzet: [HarcamaHaftalikVeri] = []
    var saatlikDagilim: [HarcamaSaatlikVeri] = []
    var haftaIciSonuKarsilastirma = HarcamaHaftaKarsilastirma()
    var donemKarsilastirma = HarcamaDonemKarsilastirma()
    var kategoriDegisimleri: [HarcamaKategoriDegisim] = []
    var butcePerformansi: [HarcamaButcePerformans] = []
    var icgoruler: [HarcamaIcgoru] = []
    
    var toplamHarcama: Double = 0
    var isLoading = false
    
    init(modelContext: ModelContext, baslangicTarihi: Date, bitisTarihi: Date) {
        self.modelContext = modelContext
        self.baslangicTarihi = baslangicTarihi
        self.bitisTarihi = bitisTarihi
        self.appSettings = AppSettings()  // ← YENİ SATIR
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(triggerFetchData),
            name: .transactionsDidChange,
            object: nil
        )
    }
    
    @objc private func triggerFetchData() {
        Task { await fetchData() }
    }
    
    func fetchData() async {
        isLoading = true
        Logger.log("Harcama Raporu: Veri çekme başladı", log: Logger.service)
        
        do {
            // Ana verileri çek
            let islemler = try await fetchTransactions()
            guard !islemler.isEmpty else {
                Logger.log("Harcama Raporu: İşlem bulunamadı", log: Logger.service)
                toplamHarcama = 0
                isLoading = false
                return
            }
            
            // Hesaplamaları yap
            calculateGeneralSummary(islemler: islemler)
            calculateCategoryAnalysis(islemler: islemler)
            calculateTimeAnalysis(islemler: islemler)
            await calculateComparison(islemler: islemler)
            generateInsights(islemler: islemler)
            
            toplamHarcama = genelOzet.toplamHarcama
            
        } catch {
            Logger.log("Harcama raporu veri çekme hatası: \(error)", log: Logger.service, type: .error)
        }
        
        isLoading = false
    }
    
    // MARK: - Veri Çekme
    
    private func fetchTransactions() async throws -> [Islem] {
        let giderTuru = IslemTuru.gider.rawValue
        let baslangic = self.baslangicTarihi
        let bitis = Calendar.current.date(byAdding: .day, value: 1, to: self.bitisTarihi) ?? self.bitisTarihi
        
        let predicate = #Predicate<Islem> { islem in
            islem.tarih >= baslangic &&
            islem.tarih < bitis &&
            islem.turRawValue == giderTuru
        }
        
        let descriptor = FetchDescriptor<Islem>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.tarih, order: .reverse)]
        )
        
        return try modelContext.fetch(descriptor)
    }
    
    // MARK: - Genel Özet
    
    private func calculateGeneralSummary(islemler: [Islem]) {
        var ozet = HarcamaGenelOzet()
        
        ozet.toplamHarcama = islemler.reduce(0) { $0 + $1.tutar }
        ozet.islemSayisi = islemler.count
        ozet.enYuksekHarcama = islemler.max(by: { $0.tutar < $1.tutar })
        
        // Günlük ortalama
        let gunSayisi = Calendar.current.dateComponents([.day], from: baslangicTarihi, to: bitisTarihi).day ?? 1
        ozet.gunlukOrtalama = ozet.toplamHarcama / Double(max(gunSayisi, 1))
        
        // Ortalama işlem tutarı
        ozet.ortalamaIslemTutari = ozet.islemSayisi > 0 ? ozet.toplamHarcama / Double(ozet.islemSayisi) : 0
        
        self.genelOzet = ozet
    }
    
    // MARK: - Kategori Analizi - TİPLER GÜNCELLENDİ
    
    private func calculateCategoryAnalysis(islemler: [Islem]) {
        let kategoriGruplari = Dictionary(grouping: islemler) { $0.kategori }
        
        var kategoriler: [HarcamaKategoriOzet] = []
        var detayliKategoriler: [HarcamaKategoriDetay] = []
        
        for (kategori, kategoriIslemleri) in kategoriGruplari {
            guard let kategori = kategori else { continue }
            
            let toplam = kategoriIslemleri.reduce(0) { $0 + $1.tutar }
            let yuzde = genelOzet.toplamHarcama > 0 ? (toplam / genelOzet.toplamHarcama) * 100 : 0
            
            // Özet için
            let ozet = HarcamaKategoriOzet(
                id: kategori.id,
                isim: kategori.isim,
                localizationKey: kategori.localizationKey,
                ikonAdi: kategori.ikonAdi,
                renk: kategori.renk,
                tutar: toplam,
                yuzde: yuzde,
                islemSayisi: kategoriIslemleri.count
            )
            kategoriler.append(ozet)
            
            // Detay için
            let gunlukDagilim = calculateDailyBreakdown(islemler: kategoriIslemleri)
            let detay = HarcamaKategoriDetay(
                id: kategori.id,
                isim: kategori.isim,
                localizationKey: kategori.localizationKey,
                ikonAdi: kategori.ikonAdi,
                renk: kategori.renk,
                toplamTutar: toplam,
                yuzde: yuzde,
                islemSayisi: kategoriIslemleri.count,
                gunlukDagilim: gunlukDagilim,
                enBuyukIslem: kategoriIslemleri.max(by: { $0.tutar < $1.tutar }),
                ortalamaIslemTutari: toplam / Double(max(kategoriIslemleri.count, 1))
            )
            detayliKategoriler.append(detay)
        }
        
        self.topKategoriler = kategoriler.sorted { $0.tutar > $1.tutar }
        self.kategoriDetaylari = detayliKategoriler.sorted { $0.toplamTutar > $1.toplamTutar }
    }
    
    // MARK: - Zaman Analizi - TİPLER GÜNCELLENDİ
    
    private func calculateTimeAnalysis(islemler: [Islem]) {
        let calendar = Calendar.current
        
        // Günlük dağılım
        let gunlukGruplar = Dictionary(grouping: islemler) { islem in
            calendar.startOfDay(for: islem.tarih)
        }
        
        var gunlukVeriler: [HarcamaGunlukVeri] = []
        var currentDate = baslangicTarihi
        
        while currentDate <= bitisTarihi {
            let gun = calendar.startOfDay(for: currentDate)
            let gunIslemleri = gunlukGruplar[gun] ?? []
            let toplam = gunIslemleri.reduce(0) { $0 + $1.tutar }
            
            gunlukVeriler.append(HarcamaGunlukVeri(
                gun: gun,
                tutar: toplam,
                islemSayisi: gunIslemleri.count
            ))
            
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }
        
        self.gunlukHarcamalar = gunlukVeriler
        
        // Haftalık özet
        let haftalikGruplar = Dictionary(grouping: gunlukVeriler) { gun in
            calendar.dateInterval(of: .weekOfYear, for: gun.gun)!.start
        }
        
        self.haftalikOzet = haftalikGruplar.map { (hafta, gunler) in
            HarcamaHaftalikVeri(
                haftaBasi: hafta,
                toplamTutar: gunler.reduce(0) { $0 + $1.tutar },
                gunSayisi: gunler.count,
                islemSayisi: gunler.reduce(0) { $0 + ($1.islemSayisi ?? 0) }
            )
        }.sorted { $0.haftaBasi < $1.haftaBasi }
        
        // Saatlik dağılım
        var saatlikToplam: [Int: (tutar: Double, sayi: Int)] = [:]
        
        for islem in islemler {
            let saat = calendar.component(.hour, from: islem.tarih)
            saatlikToplam[saat, default: (0, 0)].tutar += islem.tutar
            saatlikToplam[saat, default: (0, 0)].sayi += 1
        }
        
        self.saatlikDagilim = (0..<24).map { saat in
            let veri = saatlikToplam[saat] ?? (0, 0)
            return HarcamaSaatlikVeri(
                saat: saat,
                toplamTutar: veri.tutar,
                islemSayisi: veri.sayi,
                yuzde: genelOzet.toplamHarcama > 0 ? (veri.tutar / genelOzet.toplamHarcama) * 100 : 0
            )
        }
        
        // Hafta içi vs hafta sonu
        let haftaIciIslemler = islemler.filter { !calendar.isDateInWeekend($0.tarih) }
        let haftaSonuIslemler = islemler.filter { calendar.isDateInWeekend($0.tarih) }
        
        let haftaIciToplam = haftaIciIslemler.reduce(0) { $0 + $1.tutar }
        let haftaSonuToplam = haftaSonuIslemler.reduce(0) { $0 + $1.tutar }
        
        self.haftaIciSonuKarsilastirma = HarcamaHaftaKarsilastirma(
            haftaIciToplam: haftaIciToplam,
            haftaSonuToplam: haftaSonuToplam,
            haftaIciIslemSayisi: haftaIciIslemler.count,
            haftaSonuIslemSayisi: haftaSonuIslemler.count
        )
    }
    
    // MARK: - Karşılaştırma
    
    private func calculateComparison(islemler: [Islem]) async {
        // Önceki dönem verilerini çek
        let gunFarki = Calendar.current.dateComponents([.day], from: baslangicTarihi, to: bitisTarihi).day ?? 30
        guard let oncekiBaslangic = Calendar.current.date(byAdding: .day, value: -gunFarki - 1, to: baslangicTarihi),
              let oncekiBitis = Calendar.current.date(byAdding: .day, value: -1, to: baslangicTarihi) else { return }
        
        let giderTuru = IslemTuru.gider.rawValue
        let predicate = #Predicate<Islem> { islem in
            islem.tarih >= oncekiBaslangic &&
            islem.tarih <= oncekiBitis &&
            islem.turRawValue == giderTuru
        }
        
        do {
            let oncekiIslemler = try modelContext.fetch(FetchDescriptor(predicate: predicate))
            let oncekiToplam = oncekiIslemler.reduce(0) { $0 + $1.tutar }
            
            // Dönem karşılaştırması
            if oncekiToplam > 0 {
                let degisimTutari = genelOzet.toplamHarcama - oncekiToplam
                let degisimYuzdesi = (degisimTutari / oncekiToplam) * 100
                
                self.donemKarsilastirma = HarcamaDonemKarsilastirma(
                    oncekiDonemToplam: oncekiToplam,
                    buDonemToplam: genelOzet.toplamHarcama,
                    degisimTutari: degisimTutari,
                    degisimYuzdesi: degisimYuzdesi
                )
                
                // Genel özete ekle
                genelOzet.oncekiDonemeGoreDegisim = (
                    tutar: degisimTutari,
                    yuzde: degisimYuzdesi,
                    aciklama: degisimYuzdesi > 0 ? "spending_report.increase" : "spending_report.decrease"
                )
            }
            
            // Kategori değişimleri
            calculateCategoryChanges(mevcutIslemler: islemler, oncekiIslemler: oncekiIslemler)
            
        } catch {
            Logger.log("Karşılaştırma verisi çekilirken hata: \(error)", log: Logger.service, type: .error)
        }
        
        // Bütçe performansı
        await calculateBudgetPerformance(islemler: islemler)
    }
    
    // MARK: - İçgörüler
    
    private func generateInsights(islemler: [Islem]) {
        var icgoruler: [HarcamaIcgoru] = []
        
        // Doğru dil bundle'ını al
        let languageBundle: Bundle = {
            if let path = Bundle.main.path(forResource: appSettings.languageCode, ofType: "lproj"),
               let bundle = Bundle(path: path) {
                return bundle
            }
            return .main
        }()
        
        // En yoğun gün
        if let enYogunGun = findBusiestDay(islemler: islemler) {
            let mesajFormat = languageBundle.localizedString(
                forKey: "spending_report.insight.busiest_day",
                value: "",
                table: nil
            )
            let mesaj = String(
                format: mesajFormat,
                enYogunGun.tarih,
                formatCurrency(
                    amount: enYogunGun.tutar,
                    currencyCode: appSettings.currencyCode,
                    localeIdentifier: appSettings.languageCode
                )
            )
            
            icgoruler.append(HarcamaIcgoru(
                id: UUID(),
                tip: .bilgi,
                mesaj: mesaj,
                oncelik: 1
            ))
        }
        
        // En çok harcanan kategori
        if let topKategori = topKategoriler.first {
            let kategoriAdi = languageBundle.localizedString(
                forKey: topKategori.localizationKey ?? topKategori.isim,
                value: topKategori.isim,
                table: nil
            )
            let mesajFormat = languageBundle.localizedString(
                forKey: "spending_report.insight.top_category",
                value: "",
                table: nil
            )
            let mesaj = String(format: mesajFormat, kategoriAdi, topKategori.yuzde)
            
            icgoruler.append(HarcamaIcgoru(
                id: UUID(),
                tip: .bilgi,
                mesaj: mesaj,
                oncelik: 2
            ))
        }
        
        // Hafta sonu uyarısı
        if haftaIciSonuKarsilastirma.haftaSonuToplam > haftaIciSonuKarsilastirma.haftaIciToplam * 0.5 {
            let mesaj = languageBundle.localizedString(
                forKey: "spending_report.insight.weekend_warning",
                value: "",
                table: nil
            )
            
            icgoruler.append(HarcamaIcgoru(
                id: UUID(),
                tip: .uyari,
                mesaj: mesaj,
                oncelik: 3
            ))
        }
        
        self.icgoruler = icgoruler.sorted { $0.oncelik < $1.oncelik }
    }
    
    // MARK: - Yardımcı Fonksiyonlar
    
    private func calculateDailyBreakdown(islemler: [Islem]) -> [HarcamaGunlukVeri] {
        let calendar = Calendar.current
        let gunlukGruplar = Dictionary(grouping: islemler) { islem in
            calendar.startOfDay(for: islem.tarih)
        }
        
        return gunlukGruplar.map { (gun, gunIslemleri) in
            HarcamaGunlukVeri(
                gun: gun,
                tutar: gunIslemleri.reduce(0) { $0 + $1.tutar },
                islemSayisi: gunIslemleri.count
            )
        }.sorted { $0.gun < $1.gun }
    }
    
    private func findBusiestDay(islemler: [Islem]) -> (tarih: String, tutar: Double)? {
        let calendar = Calendar.current
        let gunlukGruplar = Dictionary(grouping: islemler) { islem in
            calendar.startOfDay(for: islem.tarih)
        }
        
        let gunlukToplamlar = gunlukGruplar.mapValues { gunIslemleri in
            gunIslemleri.reduce(0) { $0 + $1.tutar }
        }
        
        guard let enYogun = gunlukToplamlar.max(by: { $0.value < $1.value }) else { return nil }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMMM"
        formatter.locale = Locale(identifier: appSettings.languageCode) // ← DİNAMİK
        
        return (formatter.string(from: enYogun.key), enYogun.value)
    }
    
    private func calculateCategoryChanges(mevcutIslemler: [Islem], oncekiIslemler: [Islem]) {
        let mevcutKategoriler = Dictionary(grouping: mevcutIslemler) { $0.kategori }
            .compactMapValues { islemler -> Double? in
                islemler.reduce(0) { $0 + $1.tutar }
            }
        
        let oncekiKategoriler = Dictionary(grouping: oncekiIslemler) { $0.kategori }
            .compactMapValues { islemler -> Double? in
                islemler.reduce(0) { $0 + $1.tutar }
            }
        
        var degisimler: [HarcamaKategoriDegisim] = []
        
        for kategoriDetay in kategoriDetaylari {
            // Kategori detaydan Kategori nesnesini bul
            let kategoriID = kategoriDetay.id
            let mevcutKategori = mevcutKategoriler.first(where: { $0.key?.id == kategoriID })?.key
            
            let mevcut = mevcutKategoriler[mevcutKategori] ?? 0
            let onceki = oncekiKategoriler[mevcutKategori] ?? 0
            
            if onceki > 0 || mevcut > 0 {
                let degisim = mevcut - onceki
                let yuzde = onceki > 0 ? (degisim / onceki) * 100 : 100
                
                degisimler.append(HarcamaKategoriDegisim(
                    kategori: kategoriDetay,
                    oncekiTutar: onceki,
                    mevcutTutar: mevcut,
                    degisimTutari: degisim,
                    degisimYuzdesi: yuzde
                ))
            }
        }
        
        self.kategoriDegisimleri = degisimler.sorted { abs($0.degisimTutari) > abs($1.degisimTutari) }
    }
    
    private func calculateBudgetPerformance(islemler: [Islem]) async {
        // Bütçeleri çek
        do {
            let butceler = try modelContext.fetch(FetchDescriptor<Butce>())
            var performanslar: [HarcamaButcePerformans] = []
            
            for butce in butceler {
                // Bütçe kategorilerine göre harcamaları hesapla
                let butceKategoriIDleri = butce.kategoriler?.map { $0.id } ?? []
                let butceIslemleri = islemler.filter { islem in
                    guard let kategoriID = islem.kategori?.id else { return false }
                    return butceKategoriIDleri.contains(kategoriID)
                }
                
                let harcanan = butceIslemleri.reduce(0) { $0 + $1.tutar }
                let kullanımOrani = butce.limitTutar > 0 ? (harcanan / butce.limitTutar) * 100 : 0
                
                performanslar.append(HarcamaButcePerformans(
                    butce: butce,
                    harcananTutar: harcanan,
                    kalanTutar: butce.limitTutar - harcanan,
                    kullanimOrani: kullanımOrani,
                    durum: kullanımOrani > 100 ? .asildi : kullanımOrani > 80 ? .kritik : .normal
                ))
            }
            
            self.butcePerformansi = performanslar.sorted { $0.kullanimOrani > $1.kullanimOrani }
            
        } catch {
            Logger.log("Bütçe performansı hesaplanırken hata: \(error)", log: Logger.service, type: .error)
        }
    }
}
