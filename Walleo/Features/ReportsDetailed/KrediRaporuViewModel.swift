// Features/ReportsDetailed/KrediRaporuViewModel.swift

import SwiftUI
import SwiftData

@MainActor
@Observable
class KrediRaporuViewModel {
    private var modelContext: ModelContext
    var baslangicTarihi: Date
    var bitisTarihi: Date
    
    // UI veriler
    var genelOzet = KrediGenelOzet()
    var krediDetayRaporlari: [KrediDetayRaporu] = []
    var giderOlarakEklenenTaksitIDleri: Set<UUID> = []
    var aylikTaksitVerileri: [(ay: Date, tutar: Double)] = []
    var krediIstatistikleri = KrediIstatistikleri()
    var genelPerformansSkoru: Double = 0.0
    var isLoading = false
    
    init(modelContext: ModelContext, baslangicTarihi: Date, bitisTarihi: Date) {
        self.modelContext = modelContext
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
        Logger.log("Kredi Raporu: Veri çekme başladı", log: Logger.service)
        
        do {
            // Kredileri çek
            let krediler = try await fetchKrediler()
            
            // Detaylı raporları oluştur
            var raporlar: [KrediDetayRaporu] = []
            var toplamOdenen: Double = 0
            var toplamKalan: Double = 0
            var toplamKrediTutari: Double = 0
            var aktifKrediSayisi = 0
            var tamamlananKrediSayisi = 0
            
            for hesap in krediler {
                if case .kredi(let tutar, let faizTipi, let faizOrani, let taksitSayisi, let ilkTarih, let taksitler) = hesap.detay {
                    let rapor = await createDetailedKrediRaporu(
                        hesap: hesap,
                        krediTutari: tutar,
                        faizTipi: faizTipi,
                        faizOrani: faizOrani,
                        toplamTaksitSayisi: taksitSayisi,
                        ilkTaksitTarihi: ilkTarih,
                        taksitler: taksitler
                    )
                    
                    raporlar.append(rapor)
                    
                    // Özet hesaplamaları
                    if let detay = rapor.krediDetaylari {
                        toplamKrediTutari += detay.cekilenTutar
                        toplamOdenen += (detay.cekilenTutar - detay.kalanAnaparaTutari)
                        toplamKalan += detay.kalanAnaparaTutari
                        
                        if detay.kalanTaksitSayisi > 0 {
                            aktifKrediSayisi += 1
                        } else {
                            tamamlananKrediSayisi += 1
                        }
                    }
                }
            }
            
            // Gider olarak eklenen taksitleri bul
            await findAssociatedExpenseTransactions()
            
            // Aylık taksit verilerini hesapla
            calculateMonthlyPaymentData(raporlar: raporlar)
            
            // İstatistikleri hesapla
            calculateStatistics(raporlar: raporlar)
            
            // Genel özeti güncelle
            updateGeneralSummary(
                raporlar: raporlar,
                toplamKrediTutari: toplamKrediTutari,
                toplamOdenen: toplamOdenen,
                toplamKalan: toplamKalan,
                aktifKrediSayisi: aktifKrediSayisi,
                tamamlananKrediSayisi: tamamlananKrediSayisi
            )
            
            self.krediDetayRaporlari = raporlar.sorted { $0.ilerlemeYuzdesi < $1.ilerlemeYuzdesi }
            
        } catch {
            Logger.log("Kredi raporu veri çekme hatası: \(error)", log: Logger.service, type: .error)
        }
        
        isLoading = false
    }
    
    // MARK: - Veri Çekme
    
    private func fetchKrediler() async throws -> [Hesap] {
        let krediTuru = HesapTuru.kredi.rawValue
        let predicate = #Predicate<Hesap> { $0.hesapTuruRawValue == krediTuru }
        return try modelContext.fetch(FetchDescriptor(predicate: predicate))
    }
    
    // MARK: - Detaylı Rapor Oluşturma
    
    private func createDetailedKrediRaporu(
        hesap: Hesap,
        krediTutari: Double,
        faizTipi: FaizTipi,
        faizOrani: Double,
        toplamTaksitSayisi: Int,
        ilkTaksitTarihi: Date,
        taksitler: [KrediTaksitDetayi]
    ) async -> KrediDetayRaporu {
        
        // Dönem taksitleri
        let donemTaksitleri = taksitler.filter {
            $0.odemeTarihi >= baslangicTarihi && $0.odemeTarihi <= bitisTarihi
        }.sorted { $0.odemeTarihi < $1.odemeTarihi }
        
        // Ödenen taksit sayısı
        let odenenTaksitSayisi = taksitler.filter { $0.odendiMi }.count
        let kalanTaksitSayisi = toplamTaksitSayisi - odenenTaksitSayisi
        
        // Toplam ödenecek tutar (faizli)
        let toplamOdenecekTutar = taksitler.reduce(0) { $0 + $1.taksitTutari }
        let toplamFaizTutari = toplamOdenecekTutar - krediTutari
        
        // Kalan anapara
        let odenenAnapara = Double(odenenTaksitSayisi) * (krediTutari / Double(toplamTaksitSayisi))
        let kalanAnapara = krediTutari - odenenAnapara
        
        // Son ödeme tarihi
        let sonOdemeTarihi = taksitler.max { $0.odemeTarihi < $1.odemeTarihi }?.odemeTarihi
        
        // Kredi detayları
        let krediDetaylari = KrediDetaylari(
            cekilenTutar: krediTutari,
            faizTipi: faizTipi,
            faizOrani: faizOrani,
            toplamTaksitSayisi: toplamTaksitSayisi,
            ilkTaksitTarihi: ilkTaksitTarihi,
            toplamOdenecekTutar: toplamOdenecekTutar,
            toplamFaizTutari: toplamFaizTutari,
            odenenTaksitSayisi: odenenTaksitSayisi,
            kalanTaksitSayisi: kalanTaksitSayisi,
            kalanAnaparaTutari: kalanAnapara,
            sonOdemeTarihi: sonOdemeTarihi
        )
        
        // Ödeme performansı
        let performans = calculatePaymentPerformance(taksitler: taksitler)
        
        // Sonraki taksit
        let sonrakiTaksit = taksitler
            .filter { !$0.odendiMi && $0.odemeTarihi >= Date() }
            .min { $0.odemeTarihi < $1.odemeTarihi }
        
        // İlerleme yüzdesi
        let ilerlemeYuzdesi = Double(odenenTaksitSayisi) / Double(toplamTaksitSayisi) * 100
        
        return KrediDetayRaporu(
            id: hesap.id,
            hesap: hesap,
            krediDetaylari: krediDetaylari,
            donemdekiTaksitler: donemTaksitleri,
            tumTaksitler: taksitler, // YENİ SATIR
            odemePerformansi: performans,
            sonrakiTaksit: sonrakiTaksit,
            ilerlemeYuzdesi: ilerlemeYuzdesi
        )
    }
    
    // MARK: - Performans Hesaplama
    
    private func calculatePaymentPerformance(taksitler: [KrediTaksitDetayi]) -> OdemePerformansi {
        var performans = OdemePerformansi()
        let bugün = Date()
        
        for taksit in taksitler {
            if taksit.odendiMi {
                // Zamanında mı ödenmiş kontrol et (basitleştirilmiş)
                if taksit.odemeTarihi >= bugün {
                    performans.zamanindaOdenenSayisi += 1
                } else {
                    performans.gecOdenenSayisi += 1
                }
            } else if taksit.odemeTarihi < bugün {
                performans.odenmeyenSayisi += 1
            }
        }
        
        let toplamGecmis = performans.zamanindaOdenenSayisi + performans.gecOdenenSayisi + performans.odenmeyenSayisi
        if toplamGecmis > 0 {
            performans.performansSkoru = Double(performans.zamanindaOdenenSayisi) / Double(toplamGecmis) * 100
        }
        
        return performans
    }
    
    // MARK: - Aylık Veri Hesaplama
    
    private func calculateMonthlyPaymentData(raporlar: [KrediDetayRaporu]) {
        var aylikVeriler: [Date: Double] = [:]
        let calendar = Calendar.current
        
        for rapor in raporlar {
            if let detay = rapor.krediDetaylari, detay.kalanTaksitSayisi > 0 {
                // Gelecek 12 ay için projeksiyon
                for i in 0..<min(12, detay.kalanTaksitSayisi) {
                    if let ay = calendar.date(byAdding: .month, value: i, to: Date()) {
                        let ayBasi = calendar.dateInterval(of: .month, for: ay)!.start
                        aylikVeriler[ayBasi, default: 0] += detay.aylikTaksitTutari
                    }
                }
            }
        }
        
        self.aylikTaksitVerileri = aylikVeriler
            .sorted { $0.key < $1.key }
            .map { ($0.key, $0.value) }
    }
    
    // MARK: - İstatistik Hesaplama
    
    private func calculateStatistics(raporlar: [KrediDetayRaporu]) {
        var istatistikler = KrediIstatistikleri()
        var toplamOdenenFaiz: Double = 0
        var tumTaksitTutarlari: [Double] = []
        
        for rapor in raporlar {
            if let detay = rapor.krediDetaylari {
                // Ödenen faiz (basitleştirilmiş)
                let odenenFaizOrani = Double(detay.odenenTaksitSayisi) / Double(detay.toplamTaksitSayisi)
                toplamOdenenFaiz += detay.toplamFaizTutari * odenenFaizOrani
                
                // Taksit tutarları
                tumTaksitTutarlari.append(detay.aylikTaksitTutari)
            }
        }
        
        istatistikler.toplamOdenenFaiz = toplamOdenenFaiz
        istatistikler.enBuyukTaksitTutari = tumTaksitTutarlari.max() ?? 0
        istatistikler.enKucukTaksitTutari = tumTaksitTutarlari.min() ?? 0
        istatistikler.aylikOrtalamaOdeme = tumTaksitTutarlari.reduce(0, +) / Double(max(tumTaksitTutarlari.count, 1))
        
        self.krediIstatistikleri = istatistikler
    }
    
    // MARK: - Genel Özet Güncelleme
    
    private func updateGeneralSummary(
        raporlar: [KrediDetayRaporu],
        toplamKrediTutari: Double,
        toplamOdenen: Double,
        toplamKalan: Double,
        aktifKrediSayisi: Int,
        tamamlananKrediSayisi: Int
    ) {
        var ozet = KrediGenelOzet()
        
        ozet.aktifKrediSayisi = aktifKrediSayisi
        ozet.tamamlananKrediSayisi = tamamlananKrediSayisi
        ozet.toplamKrediTutari = toplamKrediTutari
        ozet.toplamOdenenTutar = toplamOdenen
        ozet.toplamKalanBorc = toplamKalan
        
        // Dönem verileri
        let donemTaksitleri = raporlar.flatMap { $0.donemdekiTaksitler }
        ozet.donemdekiToplamTaksitTutari = donemTaksitleri.reduce(0) { $0 + $1.taksitTutari }
        ozet.odenenTaksitSayisi = donemTaksitleri.filter { $0.odendiMi }.count
        ozet.odenmeyenTaksitSayisi = donemTaksitleri.filter { !$0.odendiMi && $0.odemeTarihi < Date() }.count
        ozet.odenenToplamTaksitTutari = donemTaksitleri.filter { $0.odendiMi }.reduce(0) { $0 + $1.taksitTutari }
        
        // Aylık taksit yükü
        ozet.aylikToplamTaksitYuku = raporlar.compactMap { $0.krediDetaylari?.aylikTaksitTutari }.reduce(0, +)
        
        // İlerleme
        if toplamKrediTutari > 0 {
            ozet.ilerlemeYuzdesi = (toplamOdenen / toplamKrediTutari) * 100
        }
        
        // Tahmini bitiş
        if let enUzunKredi = raporlar.compactMap({ $0.krediDetaylari }).max(by: { $0.kalanTaksitSayisi < $1.kalanTaksitSayisi }) {
            ozet.tahminiTamamlanmaTarihi = Calendar.current.date(
                byAdding: .month,
                value: enUzunKredi.kalanTaksitSayisi,
                to: Date()
            )
        }
        
        // Performans skoru
        let tumPerformanslar = raporlar.map { $0.odemePerformansi.performansSkoru }
        self.genelPerformansSkoru = tumPerformanslar.reduce(0, +) / Double(max(tumPerformanslar.count, 1))
        
        self.genelOzet = ozet
    }
    
    // MARK: - Gider Taksit Kontrolü
    
    // KrediRaporuViewModel.swift - findAssociatedExpenseTransactions fonksiyonu düzeltmesi

    private func findAssociatedExpenseTransactions() async {
        var bulunanIDler: Set<UUID> = []
        
        // Tüm kategorileri çek ve "Kredi Ödemesi" olanı bul
        do {
            let tumKategoriler = try modelContext.fetch(FetchDescriptor<Kategori>())
            guard let krediKategorisi = tumKategoriler.first(where: { $0.isim == "Kredi Ödemesi" }) else {
                Logger.log("Kredi Ödemesi kategorisi bulunamadı", log: Logger.service)
                return
            }
            
            let krediKategoriID = krediKategorisi.id
            
            for rapor in krediDetayRaporlari {
                for taksit in rapor.donemdekiTaksitler where taksit.odendiMi {
                    let taksitTutari = taksit.taksitTutari
                    
                    // İşlemleri çek ve kontrol et
                    let islemPredicate = #Predicate<Islem> { islem in
                        islem.tutar == taksitTutari &&
                        islem.kategori?.id == krediKategoriID
                    }
                    
                    let eslesenIslemler = try modelContext.fetch(FetchDescriptor(predicate: islemPredicate))
                    if !eslesenIslemler.isEmpty {
                        bulunanIDler.insert(taksit.id)
                    }
                }
            }
            
            self.giderOlarakEklenenTaksitIDleri = bulunanIDler
            
        } catch {
            Logger.log("Gider olarak eklenen taksitler aranırken hata: \(error)", log: Logger.service, type: .error)
        }
    }
    
    // MARK: - Filtreleme
    
    func filtreliKrediler(filtre: KrediFiltre) -> [KrediDetayRaporu] {
        var sonuc = krediDetayRaporlari
        
        // Aktif filtresi
        if filtre.sadecekAktifler {
            sonuc = sonuc.filter { ($0.krediDetaylari?.kalanTaksitSayisi ?? 0) > 0 }
        }
        
        // Arama
        if !filtre.aramaMetni.isEmpty {
            sonuc = sonuc.filter { $0.hesap.isim.localizedCaseInsensitiveContains(filtre.aramaMetni) }
        }
        
        // Sıralama
        switch filtre.siralama {
        case .tariheGore:
            sonuc.sort { $0.sonrakiTaksit?.odemeTarihi ?? Date.distantFuture < $1.sonrakiTaksit?.odemeTarihi ?? Date.distantFuture }
        case .tutaraGore:
            sonuc.sort { ($0.krediDetaylari?.kalanAnaparaTutari ?? 0) > ($1.krediDetaylari?.kalanAnaparaTutari ?? 0) }
        case .ilerlemeGore:
            sonuc.sort { $0.ilerlemeYuzdesi > $1.ilerlemeYuzdesi }
        }
        
        return sonuc
    }
    
    // MARK: - Takvim Verisi
    
    func odemeTakvimi(for ay: Date) -> [OdemeTakvimi] {
        let calendar = Calendar.current
        let ayBaslangici = calendar.dateInterval(of: .month, for: ay)!.start
        let ayBitisi = calendar.dateInterval(of: .month, for: ay)!.end
        
        var takvimVerisi: [Date: [OdemeTakvimi.TaksitOzeti]] = [:]
        
        for rapor in krediDetayRaporlari {
            let aylikTaksitler = rapor.tumTaksitler.filter { taksit in
                taksit.odemeTarihi >= ayBaslangici && taksit.odemeTarihi < ayBitisi
            }
            
            for taksit in aylikTaksitler {
                let gun = calendar.startOfDay(for: taksit.odemeTarihi)
                
                let taksitNo = rapor.tumTaksitler
                    .sorted { $0.odemeTarihi < $1.odemeTarihi }
                    .firstIndex(where: { $0.id == taksit.id }) ?? 0
                
                let ozet = OdemeTakvimi.TaksitOzeti(
                    krediAdi: rapor.hesap.isim,
                    taksitNo: "\(taksitNo + 1)/\(rapor.krediDetaylari?.toplamTaksitSayisi ?? 0)",
                    tutar: taksit.taksitTutari,
                    odemeTarihi: taksit.odemeTarihi,
                    odendiMi: taksit.odendiMi
                )
                
                takvimVerisi[gun, default: []].append(ozet)
            }
        }
        
        return takvimVerisi.map { (tarih, taksitler) in
            OdemeTakvimi(
                ay: tarih,
                taksitler: taksitler.sorted { $0.tutar > $1.tutar },
                toplamTutar: taksitler.reduce(0) { $0 + $1.tutar }
            )
        }.sorted { $0.ay < $1.ay }
    }
}
