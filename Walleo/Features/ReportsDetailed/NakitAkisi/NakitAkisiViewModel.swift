//
//  NakitAkisiViewModel.swift
//  Walleo
//
//  Created by Mustafa Turan on 18.07.2025.
//


// Walleo/Features/ReportsDetailed/NakitAkisi/NakitAkisiViewModel.swift

import SwiftUI
import SwiftData

@MainActor
@Observable
class NakitAkisiViewModel {
    private var modelContext: ModelContext
    var baslangicTarihi: Date
    var bitisTarihi: Date
    
    // UI'da gösterilecek veriler
    var nakitAkisiRaporu: NakitAkisiRaporu?
    var icgoruler: [NakitAkisiIcgoru] = []
    var isLoading = false
    
    // Filtreleme
    var dahilEdilecekHesaplar: Set<UUID> = []
    var transferleriDahilEt = true
    
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
        Logger.log("Nakit Akışı Raporu: Veri çekme başladı. Tarih: \(baslangicTarihi) - \(bitisTarihi)", log: Logger.service)
        
        do {
            // 1. Tüm verileri çek
            let islemler = try await fetchTransactions()
            let transferler = transferleriDahilEt ? try await fetchTransfers() : []
            let hesaplar = try await fetchAccounts()
            let kategoriler = try await fetchCategories()
            
            // 2. Günlük akış verilerini hesapla
            let gunlukAkisVerisi = calculateDailyCashFlow(
                islemler: islemler,
                transferler: transferler,
                hesaplar: hesaplar
            )
            
            // 3. İşlem tipi dağılımını hesapla
            let islemTipiDagilimi = calculateTransactionTypeDistribution(islemler: islemler)
            
            // 4. Kategori akışlarını hesapla
            let kategoriAkislari = calculateCategoryCashFlow(
                islemler: islemler,
                kategoriler: kategoriler
            )
            
            // 5. Hesap akışlarını hesapla
            let hesapAkislari = calculateAccountCashFlow(
                hesaplar: hesaplar,
                islemler: islemler,
                transferler: transferler
            )
            
            // 6. Gelecek projeksiyonunu hesapla
            let gelecekProjeksiyonu = calculateFutureProjection(
                islemler: islemler,
                gunSayisi: 30
            )
            
            // 7. Transfer özetini hesapla
            let transferOzeti = calculateTransferSummary(transferler: transferler)
            
            // 8. Toplam değerleri hesapla
            let toplamGelir = islemler.filter { $0.tur == .gelir }.reduce(0) { $0 + $1.tutar }
            let toplamGider = islemler.filter { $0.tur == .gider }.reduce(0) { $0 + $1.tutar }
            
            // 9. Raporu oluştur
            self.nakitAkisiRaporu = NakitAkisiRaporu(
                baslangicTarihi: baslangicTarihi,
                bitisTarihi: bitisTarihi,
                toplamGelir: toplamGelir,
                toplamGider: toplamGider,
                netAkis: toplamGelir - toplamGider,
                gunlukAkisVerisi: gunlukAkisVerisi,
                islemTipiDagilimi: islemTipiDagilimi,
                kategoriAkislari: kategoriAkislari,
                hesapAkislari: hesapAkislari,
                gelecekProjeksiyonu: gelecekProjeksiyonu,
                transferOzeti: transferOzeti
            )
            
            // 10. İçgörüleri oluştur
            self.icgoruler = generateInsights(rapor: self.nakitAkisiRaporu!)
            
        } catch {
            Logger.log("Nakit akışı verisi çekilirken hata: \(error)", log: Logger.service, type: .error)
        }
        
        isLoading = false
    }
    
    // MARK: - Veri Çekme Fonksiyonları
    
    private func fetchTransactions() async throws -> [Islem] {
        let baslangic = self.baslangicTarihi
        let bitis = Calendar.current.date(byAdding: .day, value: 1, to: self.bitisTarihi) ?? self.bitisTarihi
        
        let predicate = #Predicate<Islem> { islem in
            islem.tarih >= baslangic && islem.tarih < bitis
        }
        
        var islemler = try modelContext.fetch(FetchDescriptor(predicate: predicate))
        
        // Hesap filtresi uygula
        if !dahilEdilecekHesaplar.isEmpty {
            islemler = islemler.filter { islem in
                guard let hesapID = islem.hesap?.id else { return false }
                return dahilEdilecekHesaplar.contains(hesapID)
            }
        }
        
        return islemler
    }
    
    private func fetchTransfers() async throws -> [Transfer] {
        let baslangic = self.baslangicTarihi
        let bitis = Calendar.current.date(byAdding: .day, value: 1, to: self.bitisTarihi) ?? self.bitisTarihi
        
        let predicate = #Predicate<Transfer> { transfer in
            transfer.tarih >= baslangic && transfer.tarih < bitis
        }
        
        return try modelContext.fetch(FetchDescriptor(predicate: predicate))
    }
    
    private func fetchAccounts() async throws -> [Hesap] {
        return try modelContext.fetch(FetchDescriptor<Hesap>())
    }
    
    private func fetchCategories() async throws -> [Kategori] {
        return try modelContext.fetch(FetchDescriptor<Kategori>())
    }
    
    // MARK: - Hesaplama Fonksiyonları
    
    private func calculateDailyCashFlow(
        islemler: [Islem],
        transferler: [Transfer],
        hesaplar: [Hesap]
    ) -> [GunlukNakitAkisi] {
        let calendar = Calendar.current
        var gunlukVeriler: [Date: GunlukNakitAkisi] = [:]
        var kumulatifBakiye = 0.0
        
        // Başlangıç bakiyelerini hesapla
        for hesap in hesaplar {
            if dahilEdilecekHesaplar.isEmpty || dahilEdilecekHesaplar.contains(hesap.id) {
                kumulatifBakiye += hesap.baslangicBakiyesi
            }
        }
        
        // Her gün için boş veri oluştur
        var currentDate = baslangicTarihi
        while currentDate <= bitisTarihi {
            let gunBaslangici = calendar.startOfDay(for: currentDate)
            gunlukVeriler[gunBaslangici] = GunlukNakitAkisi(
                tarih: gunBaslangici,
                gelir: 0,
                gider: 0,
                netAkis: 0,
                kumulatifBakiye: kumulatifBakiye,
                normalGelir: 0,
                normalGider: 0,
                taksitliGelir: 0,
                taksitliGider: 0,
                tekrarliGelir: 0,
                tekrarliGider: 0
            )
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }
        
        // İşlemleri günlere dağıt
        for islem in islemler {
            let gunBaslangici = calendar.startOfDay(for: islem.tarih)
            guard var gunlukVeri = gunlukVeriler[gunBaslangici] else { continue }
            
            if islem.tur == .gelir {
                gunlukVeri = GunlukNakitAkisi(
                    tarih: gunlukVeri.tarih,
                    gelir: gunlukVeri.gelir + islem.tutar,
                    gider: gunlukVeri.gider,
                    netAkis: gunlukVeri.netAkis,
                    kumulatifBakiye: gunlukVeri.kumulatifBakiye,
                    normalGelir: gunlukVeri.normalGelir + (islem.taksitliMi || islem.tekrar != .tekSeferlik ? 0 : islem.tutar),
                    normalGider: gunlukVeri.normalGider,
                    taksitliGelir: gunlukVeri.taksitliGelir + (islem.taksitliMi ? islem.tutar : 0),
                    taksitliGider: gunlukVeri.taksitliGider,
                    tekrarliGelir: gunlukVeri.tekrarliGelir + (islem.tekrar != .tekSeferlik ? islem.tutar : 0),
                    tekrarliGider: gunlukVeri.tekrarliGider
                )
            } else {
                gunlukVeri = GunlukNakitAkisi(
                    tarih: gunlukVeri.tarih,
                    gelir: gunlukVeri.gelir,
                    gider: gunlukVeri.gider + islem.tutar,
                    netAkis: gunlukVeri.netAkis,
                    kumulatifBakiye: gunlukVeri.kumulatifBakiye,
                    normalGelir: gunlukVeri.normalGelir,
                    normalGider: gunlukVeri.normalGider + (islem.taksitliMi || islem.tekrar != .tekSeferlik ? 0 : islem.tutar),
                    taksitliGelir: gunlukVeri.taksitliGelir,
                    taksitliGider: gunlukVeri.taksitliGider + (islem.taksitliMi ? islem.tutar : 0),
                    tekrarliGelir: gunlukVeri.tekrarliGelir,
                    tekrarliGider: gunlukVeri.tekrarliGider + (islem.tekrar != .tekSeferlik ? islem.tutar : 0)
                )
            }
            
            gunlukVeriler[gunBaslangici] = gunlukVeri
        }
        
        // Net akış ve kümülatif bakiyeyi hesapla
        let sortedDates = gunlukVeriler.keys.sorted()
        for (index, tarih) in sortedDates.enumerated() {
            guard var gunlukVeri = gunlukVeriler[tarih] else { continue }
            
            let netAkis = gunlukVeri.gelir - gunlukVeri.gider
            kumulatifBakiye += netAkis
            
            gunlukVeriler[tarih] = GunlukNakitAkisi(
                tarih: gunlukVeri.tarih,
                gelir: gunlukVeri.gelir,
                gider: gunlukVeri.gider,
                netAkis: netAkis,
                kumulatifBakiye: kumulatifBakiye,
                normalGelir: gunlukVeri.normalGelir,
                normalGider: gunlukVeri.normalGider,
                taksitliGelir: gunlukVeri.taksitliGelir,
                taksitliGider: gunlukVeri.taksitliGider,
                tekrarliGelir: gunlukVeri.tekrarliGelir,
                tekrarliGider: gunlukVeri.tekrarliGider
            )
        }
        
        return sortedDates.compactMap { gunlukVeriler[$0] }
    }
    
    private func calculateTransactionTypeDistribution(islemler: [Islem]) -> IslemTipiDagilimi {
        let normalIslemler = islemler.filter { !$0.taksitliMi && $0.tekrar == .tekSeferlik }
        let taksitliIslemler = islemler.filter { $0.taksitliMi }
        let tekrarliIslemler = islemler.filter { $0.tekrar != .tekSeferlik }
        
        let toplamTutar = islemler.reduce(0) { $0 + $1.tutar }
        
        return IslemTipiDagilimi(
            normalIslemler: createTransactionTypeSummary(islemler: normalIslemler, toplamTutar: toplamTutar),
            taksitliIslemler: createTransactionTypeSummary(islemler: taksitliIslemler, toplamTutar: toplamTutar),
            tekrarliIslemler: createTransactionTypeSummary(islemler: tekrarliIslemler, toplamTutar: toplamTutar)
        )
    }
    
    private func createTransactionTypeSummary(islemler: [Islem], toplamTutar: Double) -> IslemTipiDagilimi.IslemTipiOzet {
        let gelirler = islemler.filter { $0.tur == .gelir }
        let giderler = islemler.filter { $0.tur == .gider }
        let toplamGelir = gelirler.reduce(0) { $0 + $1.tutar }
        let toplamGider = giderler.reduce(0) { $0 + $1.tutar }
        let tipiToplami = toplamGelir + toplamGider
        
        return IslemTipiDagilimi.IslemTipiOzet(
            gelirSayisi: gelirler.count,
            giderSayisi: giderler.count,
            toplamGelir: toplamGelir,
            toplamGider: toplamGider,
            netEtki: toplamGelir - toplamGider,
            yuzdePayi: toplamTutar > 0 ? (tipiToplami / toplamTutar) * 100 : 0
        )
    }
    
    private func calculateCategoryCashFlow(
        islemler: [Islem],
        kategoriler: [Kategori]
    ) -> [KategoriNakitAkisi] {
        var kategoriAkislari: [KategoriNakitAkisi] = []
        
        for kategori in kategoriler {
            let kategoriIslemleri = islemler.filter { $0.kategori?.id == kategori.id }
            guard !kategoriIslemleri.isEmpty else { continue }
            
            let toplamTutar = kategoriIslemleri.reduce(0) { $0 + ($1.tur == .gelir ? $1.tutar : -$1.tutar) }
            
            // Trend verisi için günlük toplamları hesapla
            let gunlukGruplar = Dictionary(grouping: kategoriIslemleri) { islem in
                Calendar.current.startOfDay(for: islem.tarih)
            }
            
            let trendNoktalari = gunlukGruplar.map { (tarih, islemler) in
                let gunlukToplam = islemler.reduce(0) { $0 + ($1.tur == .gelir ? $1.tutar : -$1.tutar) }
                return KategoriNakitAkisi.TrendNokta(tarih: tarih, tutar: gunlukToplam)
            }.sorted { $0.tarih < $1.tarih }
            
            let akis = KategoriNakitAkisi(
                id: kategori.id,
                kategori: kategori,
                toplamTutar: toplamTutar,
                islemSayisi: kategoriIslemleri.count,
                ortalamaIslemTutari: toplamTutar / Double(kategoriIslemleri.count),
                akisTrendi: trendNoktalari,
                enBuyukIslem: kategoriIslemleri.max { $0.tutar < $1.tutar }
            )
            
            kategoriAkislari.append(akis)
        }
        
        return kategoriAkislari.sorted { abs($0.toplamTutar) > abs($1.toplamTutar) }
    }
    
    private func calculateAccountCashFlow(
        hesaplar: [Hesap],
        islemler: [Islem],
        transferler: [Transfer]
    ) -> [HesapNakitAkisi] {
        var hesapAkislari: [HesapNakitAkisi] = []
        let gunSayisi = Calendar.current.dateComponents([.day], from: baslangicTarihi, to: bitisTarihi).day ?? 1
        
        for hesap in hesaplar {
            if !dahilEdilecekHesaplar.isEmpty && !dahilEdilecekHesaplar.contains(hesap.id) {
                continue
            }
            
            let hesapIslemleri = islemler.filter { $0.hesap?.id == hesap.id }
            let gelenTransferler = transferler.filter { $0.hedefHesap?.id == hesap.id }
            let gidenTransferler = transferler.filter { $0.kaynakHesap?.id == hesap.id }
            
            let gelirler = hesapIslemleri.filter { $0.tur == .gelir }.reduce(0) { $0 + $1.tutar }
            let giderler = hesapIslemleri.filter { $0.tur == .gider }.reduce(0) { $0 + $1.tutar }
            let gelenTransferToplam = gelenTransferler.reduce(0) { $0 + $1.tutar }
            let gidenTransferToplam = gidenTransferler.reduce(0) { $0 + $1.tutar }
            
            let toplamGiris = gelirler + gelenTransferToplam
            let toplamCikis = giderler + gidenTransferToplam
            let netDegisim = toplamGiris - toplamCikis
            let donemSonuBakiyesi = hesap.baslangicBakiyesi + netDegisim
            
            let akis = HesapNakitAkisi(
                id: hesap.id,
                hesap: hesap,
                baslangicBakiyesi: hesap.baslangicBakiyesi,
                donemSonuBakiyesi: donemSonuBakiyesi,
                toplamGiris: toplamGiris,
                toplamCikis: toplamCikis,
                netDegisim: netDegisim,
                islemSayisi: hesapIslemleri.count,
                gunlukOrtalama: netDegisim / Double(gunSayisi)
            )
            
            hesapAkislari.append(akis)
        }
        
        return hesapAkislari.sorted { abs($0.netDegisim) > abs($1.netDegisim) }
    }
    
    private func calculateFutureProjection(islemler: [Islem], gunSayisi: Int) -> GelecekProjeksiyonu {
        let tekrarliIslemler = islemler.filter { $0.tekrar != .tekSeferlik }
        var gunlukProjeksiyonlar: [GelecekProjeksiyonu.GunlukProjeksiyon] = []
        var kumulatifBakiye = nakitAkisiRaporu?.gunlukAkisVerisi.last?.kumulatifBakiye ?? 0
        
        let calendar = Calendar.current
        var tahminiToplamGelir = 0.0
        var tahminiToplamGider = 0.0
        
        for gunOffset in 1...gunSayisi {
            guard let projeksiyonTarihi = calendar.date(byAdding: .day, value: gunOffset, to: bitisTarihi) else { continue }
            
            var gunlukGelir = 0.0
            var gunlukGider = 0.0
            
            // Tekrarlı işlemleri projekte et
            for islem in tekrarliIslemler {
                if shouldProjectTransaction(islem: islem, tarih: projeksiyonTarihi) {
                    if islem.tur == .gelir {
                        gunlukGelir += islem.tutar
                    } else {
                        gunlukGider += islem.tutar
                    }
                }
            }
            
            let netAkis = gunlukGelir - gunlukGider
            kumulatifBakiye += netAkis
            
            tahminiToplamGelir += gunlukGelir
            tahminiToplamGider += gunlukGider
            
            gunlukProjeksiyonlar.append(GelecekProjeksiyonu.GunlukProjeksiyon(
                tarih: projeksiyonTarihi,
                tahminiGelir: gunlukGelir,
                tahminiGider: gunlukGider,
                tahminiKumulatifBakiye: kumulatifBakiye
            ))
        }
        
        // Risk seviyesini belirle
        let riskSeviyesi: GelecekProjeksiyonu.RiskSeviyesi
        if kumulatifBakiye < 0 {
            riskSeviyesi = .yuksek
        } else if kumulatifBakiye < 1000 { // Bu değer kullanıcıya göre ayarlanabilir
            riskSeviyesi = .orta
        } else {
            riskSeviyesi = .dusuk
        }
        
        return GelecekProjeksiyonu(
            projeksiyonSuresi: gunSayisi,
            tahminiGelir: tahminiToplamGelir,
            tahminiGider: tahminiToplamGider,
            tahminiNetAkis: tahminiToplamGelir - tahminiToplamGider,
            gunlukProjeksiyon: gunlukProjeksiyonlar,
            riskSeviyesi: riskSeviyesi
        )
    }
    
    private func shouldProjectTransaction(islem: Islem, tarih: Date) -> Bool {
        let calendar = Calendar.current
        
        switch islem.tekrar {
        case .herAy:
            return calendar.component(.day, from: islem.tarih) == calendar.component(.day, from: tarih)
        case .her3Ay:
            let monthDiff = calendar.dateComponents([.month], from: islem.tarih, to: tarih).month ?? 0
            return monthDiff % 3 == 0 && calendar.component(.day, from: islem.tarih) == calendar.component(.day, from: tarih)
        case .her6Ay:
            let monthDiff = calendar.dateComponents([.month], from: islem.tarih, to: tarih).month ?? 0
            return monthDiff % 6 == 0 && calendar.component(.day, from: islem.tarih) == calendar.component(.day, from: tarih)
        case .herYil:
            return calendar.component(.month, from: islem.tarih) == calendar.component(.month, from: tarih) &&
                   calendar.component(.day, from: islem.tarih) == calendar.component(.day, from: tarih)
        default:
            return false
        }
    }
    
    private func calculateTransferSummary(transferler: [Transfer]) -> TransferOzeti {
        let toplamTutar = transferler.reduce(0) { $0 + $1.tutar }
        
        // Transfer detaylarını hesapla
        var transferGruplari: [String: (kaynak: Hesap, hedef: Hesap, tutar: Double, sayi: Int)] = [:]
        
        for transfer in transferler {
            guard let kaynak = transfer.kaynakHesap, let hedef = transfer.hedefHesap else { continue }
            let key = "\(kaynak.id)-\(hedef.id)"
            
            if var grup = transferGruplari[key] {
                grup.tutar += transfer.tutar
                grup.sayi += 1
                transferGruplari[key] = grup
            } else {
                transferGruplari[key] = (kaynak, hedef, transfer.tutar, 1)
            }
        }
        
        let detaylar = transferGruplari.values.map { grup in
            TransferOzeti.TransferDetay(
                kaynakHesap: grup.kaynak,
                hedefHesap: grup.hedef,
                toplamTutar: grup.tutar,
                islemSayisi: grup.sayi
            )
        }.sorted { $0.toplamTutar > $1.toplamTutar }
        
        let enSik = detaylar.max { $0.islemSayisi < $1.islemSayisi }
        
        return TransferOzeti(
            toplamTransferSayisi: transferler.count,
            toplamTransferTutari: toplamTutar,
            enSikTransferYapilan: enSik.map { ($0.kaynakHesap, $0.hedefHesap) },
            transferDetaylari: detaylar
        )
    }
    
    private func generateInsights(rapor: NakitAkisiRaporu) -> [NakitAkisiIcgoru] {
        var icgoruler: [NakitAkisiIcgoru] = []
        let currencyCode = "TRY" // Bu değeri AppSettings'ten almalısınız
        let localeIdentifier = "tr_TR" // Bu değeri AppSettings'ten almalısınız

        // 1. Net akış durumu
        if rapor.netAkis > 0 {
            let param = formatCurrency(amount: rapor.netAkis, currencyCode: currencyCode, localeIdentifier: localeIdentifier)
            icgoruler.append(NakitAkisiIcgoru(
                tip: .pozitifAkis,
                baslik: "cashflow.insight.positive_flow",
                mesajKey: "cashflow.insight.positive_flow_message", // Değişti
                parametreler: [param],                              // Değişti
                oncelik: 1,
                ikon: "arrow.up.circle.fill",
                renk: .green
            ))
        } else if rapor.netAkis < 0 {
            let param = formatCurrency(amount: abs(rapor.netAkis), currencyCode: currencyCode, localeIdentifier: localeIdentifier)
            icgoruler.append(NakitAkisiIcgoru(
                tip: .negatifAkis,
                baslik: "cashflow.insight.negative_flow",
                mesajKey: "cashflow.insight.negative_flow_message", // Değişti
                parametreler: [param],                              // Değişti
                oncelik: 1,
                ikon: "arrow.down.circle.fill",
                renk: .red
            ))
        }
        
        // 2. Taksitli işlem uyarısı
        let taksitliOran = rapor.islemTipiDagilimi.taksitliIslemler.yuzdePayi
        if taksitliOran > 30 {
            let param = String(format: "%.1f", taksitliOran)
            icgoruler.append(NakitAkisiIcgoru(
                tip: .yuksekTaksit,
                baslik: "cashflow.insight.high_installment",
                mesajKey: "cashflow.insight.high_installment_message", // Değişti
                parametreler: [param],                                 // Değişti
                oncelik: 2,
                ikon: "creditcard.viewfinder",
                renk: .orange
            ))
        }
        
        // 3. Projeksiyon uyarısı
        if rapor.gelecekProjeksiyonu.riskSeviyesi == .yuksek {
            icgoruler.append(NakitAkisiIcgoru(
                tip: .projeksiyonUyari,
                baslik: "cashflow.insight.projection_warning",
                mesajKey: "cashflow.insight.projection_warning_message", // Değişti
                parametreler: [],                                        // Değişti
                oncelik: 1,
                ikon: "exclamationmark.triangle.fill",
                renk: .red
            ))
        }
        
        return icgoruler.sorted { $0.oncelik < $1.oncelik }
    }
}
