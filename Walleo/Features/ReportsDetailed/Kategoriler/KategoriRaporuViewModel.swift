import SwiftUI
import SwiftData

@MainActor
@Observable
class KategoriRaporuViewModel {
    private var modelContext: ModelContext
    var appSettings: AppSettings
    var baslangicTarihi: Date
    var bitisTarihi: Date
    
    // UI'da gösterilecek veriler
    var ozet = KategoriRaporOzet(
        toplamKategoriSayisi: 0,
        aktifKategoriSayisi: 0,
        toplamHarcama: 0,
        toplamGelir: 0,
        enCokHarcananKategori: nil,
        enCokHarcananKategoriTutar: 0,
        enCokIslemYapilanKategori: nil,
        enCokIslemYapilanKategoriSayi: 0,
        enCokGelirGetiren: nil
    )
    var giderKategorileri: [KategoriRaporVerisi] = []
    var gelirKategorileri: [KategoriRaporVerisi] = []
    var kategoriKarsilastirmalari: [KategoriKarsilastirma] = []
    var isLoading = false
    
    // Filtreleme
    var secilenTur: IslemTuru = .gider
    var minimumIslemSayisi: Int = 0
    
    init(modelContext: ModelContext, baslangicTarihi: Date, bitisTarihi: Date, appSettings: AppSettings = AppSettings()) {
        self.modelContext = modelContext
        self.appSettings = appSettings
        self.baslangicTarihi = baslangicTarihi
        self.bitisTarihi = bitisTarihi
        
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
        Logger.log("Kategori Raporu: Veri çekme başladı. Tarih: \(baslangicTarihi) - \(bitisTarihi)", log: Logger.service)
        
        do {
            // 1. Tüm kategorileri çek
            let kategoriler = try modelContext.fetch(FetchDescriptor<Kategori>())
            
            // 2. Belirtilen tarih aralığındaki işlemleri çek
            let islemler = await fetchTransactions()
            
            // 3. Önceki dönem işlemlerini çek (karşılaştırma için)
            let oncekiDonemIslemleri = await fetchPreviousPeriodTransactions()
            
            // 4. Her kategori için detaylı analiz yap
            var giderAnalizleri: [KategoriRaporVerisi] = []
            var gelirAnalizleri: [KategoriRaporVerisi] = []
            
            for kategori in kategoriler {
                let kategoriIslemleri = islemler.filter { $0.kategori?.id == kategori.id }
                
                if kategoriIslemleri.count >= minimumIslemSayisi && !kategoriIslemleri.isEmpty {
                    let analiz = analyzeCategory(
                        kategori: kategori,
                        islemler: kategoriIslemleri
                    )
                    
                    if kategori.tur == .gider {
                        giderAnalizleri.append(analiz)
                    } else {
                        gelirAnalizleri.append(analiz)
                    }
                }
            }
            
            // 5. Sıralama (tutara göre)
            self.giderKategorileri = giderAnalizleri.sorted { $0.toplamTutar > $1.toplamTutar }
            self.gelirKategorileri = gelirAnalizleri.sorted { $0.toplamTutar > $1.toplamTutar }
            
            // 6. Karşılaştırma verilerini oluştur
            self.kategoriKarsilastirmalari = createComparisons(
                mevcutIslemler: islemler,
                oncekiIslemler: oncekiDonemIslemleri,
                kategoriler: kategoriler
            )
            
            // 7. Özet bilgileri hesapla
            self.ozet = calculateSummary(
                kategoriler: kategoriler,
                giderAnalizleri: giderAnalizleri,
                gelirAnalizleri: gelirAnalizleri
            )
            
        } catch {
            Logger.log("Kategori raporu verisi çekilirken hata: \(error)", log: Logger.service, type: .error)
        }
        
        isLoading = false
    }
    
    func updateComparisons(for tur: IslemTuru) async {
        do {
            let islemler = await fetchTransactions()
            let oncekiDonemIslemleri = await fetchPreviousPeriodTransactions()
            let kategoriler = try modelContext.fetch(FetchDescriptor<Kategori>())
            
            self.kategoriKarsilastirmalari = createComparisons(
                mevcutIslemler: islemler,
                oncekiIslemler: oncekiDonemIslemleri,
                kategoriler: kategoriler,
                turFiltresi: tur
            )
        } catch {
            Logger.log("Karşılaştırma güncellenirken hata: \(error)", log: Logger.service, type: .error)
        }
    }
    
    private func fetchTransactions() async -> [Islem] {
        let baslangic = self.baslangicTarihi
        let bitis = Calendar.current.date(byAdding: .day, value: 1, to: self.bitisTarihi) ?? self.bitisTarihi
        
        let predicate = #Predicate<Islem> { islem in
            islem.tarih >= baslangic && islem.tarih < bitis
        }
        
        do {
            return try modelContext.fetch(FetchDescriptor(predicate: predicate))
        } catch {
            Logger.log("İşlemler çekilirken hata: \(error)", log: Logger.service, type: .error)
            return []
        }
    }
    
    private func fetchPreviousPeriodTransactions() async -> [Islem] {
        let gunFarki = Calendar.current.dateComponents([.day], from: baslangicTarihi, to: bitisTarihi).day ?? 30
        let oncekiBaslangic = Calendar.current.date(byAdding: .day, value: -gunFarki - 1, to: baslangicTarihi) ?? baslangicTarihi
        let oncekiBitis = Calendar.current.date(byAdding: .day, value: -1, to: baslangicTarihi) ?? baslangicTarihi
        
        let predicate = #Predicate<Islem> { islem in
            islem.tarih >= oncekiBaslangic && islem.tarih <= oncekiBitis
        }
        
        do {
            return try modelContext.fetch(FetchDescriptor(predicate: predicate))
        } catch {
            return []
        }
    }
    
    private func analyzeCategory(kategori: Kategori, islemler: [Islem]) -> KategoriRaporVerisi {
        let toplamTutar = islemler.reduce(0) { $0 + $1.tutar }
        let gunSayisi = Calendar.current.dateComponents([.day], from: baslangicTarihi, to: bitisTarihi).day ?? 1
        
        return KategoriRaporVerisi(
            kategori: kategori,
            toplamTutar: toplamTutar,
            islemSayisi: islemler.count,
            ortalamaTutar: toplamTutar / Double(max(islemler.count, 1)),
            gunlukOrtalama: toplamTutar / Double(max(gunSayisi, 1)),
            aylikTrend: calculateMonthlyTrend(islemler: islemler),
            enSikKullanilanIsimler: calculateFrequentNames(islemler: islemler),
            gunlereGoreDagilim: calculateDailyDistribution(islemler: islemler),
            saatlereGoreDagilim: calculateHourlyDistribution(islemler: islemler)
        )
    }
    
    private func calculateMonthlyTrend(islemler: [Islem]) -> [AylikTrendNokta] {
        let calendar = Calendar.current
        var aylikGruplar: [Date: (tutar: Double, sayi: Int)] = [:]
        
        for islem in islemler {
            let ayBasi = calendar.dateInterval(of: .month, for: islem.tarih)!.start
            aylikGruplar[ayBasi, default: (0, 0)].tutar += islem.tutar
            aylikGruplar[ayBasi, default: (0, 0)].sayi += 1
        }
        
        return aylikGruplar.map { AylikTrendNokta(ay: $0.key, tutar: $0.value.tutar, islemSayisi: $0.value.sayi) }
            .sorted { $0.ay < $1.ay }
    }
    
    private func calculateFrequentNames(islemler: [Islem]) -> [IsimFrekansi] {
        var isimGruplari: [String: [Islem]] = [:]
        
        for islem in islemler {
            let temizIsim = islem.isim.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            isimGruplari[temizIsim, default: []].append(islem)
        }
        
        return isimGruplari.map { (isim, islemler) in
            let toplamTutar = islemler.reduce(0) { $0 + $1.tutar }
            return IsimFrekansi(
                isim: islemler.first?.isim ?? isim,
                frekans: islemler.count,
                toplamTutar: toplamTutar,
                ortalamatutar: toplamTutar / Double(islemler.count)
            )
        }
        .sorted { $0.frekans > $1.frekans }
        .prefix(10)
        .map { $0 }
    }
    
    private func calculateDailyDistribution(islemler: [Islem]) -> [GunlukDagilim] {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: appSettings.languageCode)
        formatter.dateFormat = "EEEE" // Tam gün adı
        
        var gunlikGruplar: [Int: (tutar: Double, sayi: Int)] = [:]
        
        for islem in islemler {
            let gun = calendar.component(.weekday, from: islem.tarih) // 1=Pazar, 2=Pzt...
            gunlikGruplar[gun, default: (0, 0)].tutar += islem.tutar
            gunlikGruplar[gun, default: (0, 0)].sayi += 1
        }
        
        // Haftanın günlerini doğru sırayla oluştur (Lokalizasyon için düzeltildi)
        var gunler: [GunlukDagilim] = []
        let firstWeekday = calendar.firstWeekday // Genellikle Pazar=1, bazı yerlerde Pzt=2
        var gunSirasi: [Int] = []
        
        for i in 0..<7 {
            var gunIndex = firstWeekday + i
            if gunIndex > 7 {
                gunIndex -= 7
            }
            gunSirasi.append(gunIndex)
        }

        for gunIndex in gunSirasi {
            let veri = gunlikGruplar[gunIndex] ?? (tutar: 0, sayi: 0)
            
            // Bu günün adını almak için bir tarih oluştur
            var components = DateComponents()
            components.weekday = gunIndex
            
            if let tarih = calendar.nextDate(after: Date(), matching: components, matchingPolicy: .nextTime) {
                let gunAdi = formatter.string(from: tarih)
                gunler.append(GunlukDagilim(
                    gunAdi: gunAdi,
                    tutar: veri.tutar,
                    islemSayisi: veri.sayi
                ))
            }
        }
        
        return gunler
    }
    
    private func calculateHourlyDistribution(islemler: [Islem]) -> [SaatlikDagilim] {
        let calendar = Calendar.current
        var saatlikGruplar: [Int: (tutar: Double, sayi: Int)] = [:]
        
        for islem in islemler {
            let saat = calendar.component(.hour, from: islem.tarih)
            saatlikGruplar[saat, default: (0, 0)].tutar += islem.tutar
            saatlikGruplar[saat, default: (0, 0)].sayi += 1
        }
        
        return (0..<24).map { saat in
            let veri = saatlikGruplar[saat] ?? (0, 0)
            return SaatlikDagilim(saat: saat, tutar: veri.tutar, islemSayisi: veri.sayi)
        }
    }
    
    private func createComparisons(
        mevcutIslemler: [Islem],
        oncekiIslemler: [Islem],
        kategoriler: [Kategori],
        turFiltresi: IslemTuru? = nil
    ) -> [KategoriKarsilastirma] {
        var karsilastirmalar: [KategoriKarsilastirma] = []
        
        // Eğer tür filtresi verilmişse onu kullan, yoksa viewModel'deki secilenTur'u kullan
        let filtrelenenTur = turFiltresi ?? self.secilenTur
        
        // Mevcut dönem kategori sıralaması
        let mevcutSiralama = Dictionary(
            grouping: mevcutIslemler.filter { $0.tur == filtrelenenTur },
            by: { $0.kategori }
        ).compactMapValues { islemler in
            islemler.reduce(0) { $0 + $1.tutar }
        }.sorted { $0.value > $1.value }
        
        // Önceki dönem kategori sıralaması
        let oncekiSiralama = Dictionary(
            grouping: oncekiIslemler.filter { $0.tur == filtrelenenTur },
            by: { $0.kategori }
        ).compactMapValues { islemler in
            islemler.reduce(0) { $0 + $1.tutar }
        }.sorted { $0.value > $1.value }
        
        for (index, (kategori, mevcutTutar)) in mevcutSiralama.enumerated() {
            guard let kategori = kategori else { continue }
            
            let oncekiTutar = oncekiSiralama.first { $0.key?.id == kategori.id }?.value ?? 0
            let oncekiIndex = oncekiSiralama.firstIndex { $0.key?.id == kategori.id } ?? -1
            
            let degisimYuzdesi = oncekiTutar > 0 ? ((mevcutTutar - oncekiTutar) / oncekiTutar) * 100 : 0
            
            karsilastirmalar.append(KategoriKarsilastirma(
                kategori: kategori,
                mevcutDonemTutar: mevcutTutar,
                oncekiDonemTutar: oncekiTutar,
                degisimYuzdesi: degisimYuzdesi,
                siralama: index + 1,
                oncekiSiralama: oncekiIndex + 1
            ))
        }
        
        return karsilastirmalar
    }
    
    private func calculateSummary(
        kategoriler: [Kategori],
        giderAnalizleri: [KategoriRaporVerisi],
        gelirAnalizleri: [KategoriRaporVerisi]
    ) -> KategoriRaporOzet {
        let toplamHarcama = giderAnalizleri.reduce(0) { $0 + $1.toplamTutar }
        let toplamGelir = gelirAnalizleri.reduce(0) { $0 + $1.toplamTutar }
        
        // En çok harcanan kategori (tutar olarak)
        let enCokHarcananRapor = giderAnalizleri.max { $0.toplamTutar < $1.toplamTutar }
        let enCokHarcananKategori = enCokHarcananRapor?.kategori
        let enCokHarcananTutar = enCokHarcananRapor?.toplamTutar ?? 0
        
        // En çok işlem yapılan kategori
        let enCokIslemYapilanRapor = giderAnalizleri.max { $0.islemSayisi < $1.islemSayisi }
        let enCokIslemYapilanKategori = enCokIslemYapilanRapor?.kategori
        let enCokIslemYapilanSayi = enCokIslemYapilanRapor?.islemSayisi ?? 0
        
        return KategoriRaporOzet(
            toplamKategoriSayisi: kategoriler.count,
            aktifKategoriSayisi: giderAnalizleri.count + gelirAnalizleri.count,
            toplamHarcama: toplamHarcama,
            toplamGelir: toplamGelir,
            enCokHarcananKategori: enCokHarcananKategori,
            enCokHarcananKategoriTutar: enCokHarcananTutar,
            enCokIslemYapilanKategori: enCokIslemYapilanKategori,
            enCokIslemYapilanKategoriSayi: enCokIslemYapilanSayi,
            enCokGelirGetiren: gelirAnalizleri.first?.kategori
        )
    }
}
