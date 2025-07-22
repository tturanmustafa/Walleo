// Walleo/Features/ReportsDetailed/KrediKartiRaporuViewModel.swift

import SwiftUI
import SwiftData

@MainActor
@Observable
class KrediKartiRaporuViewModel {
    private var modelContext: ModelContext
    var baslangicTarihi: Date
    var bitisTarihi: Date
    
    // Arayüzün kullanacağı, işlenmiş veriler
    var genelOzet = KrediKartiGenelOzet()
    var kartDetayRaporlari: [KartDetayRaporu] = []
    var isLoading = false
    
    // Önceki dönem verileri (karşılaştırma için)
    private var oncekiDonemToplam: Double = 0
    
    init(modelContext: ModelContext, baslangicTarihi: Date, bitisTarihi: Date) {
        self.modelContext = modelContext
        self.baslangicTarihi = baslangicTarihi
        self.bitisTarihi = bitisTarihi
        
        // Veri değişikliği bildirimini dinle
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
        Logger.log("KrediKarti Raporu: Veri çekme başladı. Tarih aralığı: \(baslangicTarihi) - \(bitisTarihi)", log: Logger.service)
        
        do {
            // 1. Kredi kartı hesaplarını çek
            let kartHesaplari = try await fetchCreditCardAccounts()
            guard !kartHesaplari.isEmpty else {
                Logger.log("KrediKarti Raporu: Hiç kredi kartı hesabı bulunamadı", log: Logger.service)
                isLoading = false
                return
            }
            
            // 2. İşlemleri çek
            let tumIslemler = try await fetchTransactions(for: kartHesaplari)
            
            // 3. Transferleri çek (kredi kartı ödemeleri için)
            let transferler = try await fetchTransfers(for: kartHesaplari)
            
            // 4. Önceki dönem verilerini çek (karşılaştırma için)
            await fetchPreviousPeriodData(for: kartHesaplari)
            
            // 5. Hesaplamaları yap
            hesaplamalariYap(
                kartHesaplari: kartHesaplari,
                tumIslemler: tumIslemler,
                transferler: transferler
            )
            
        } catch {
            Logger.log("Detaylı Raporlar için veri çekilirken hata: \(error.localizedDescription)", log: Logger.service, type: .error)
        }
        
        isLoading = false
        Logger.log("KrediKarti Raporu: Veri çekme tamamlandı. Rapor sayısı: \(kartDetayRaporlari.count)", log: Logger.service)
    }
    
    // MARK: - Veri Çekme Fonksiyonları
    
    private func fetchCreditCardAccounts() async throws -> [Hesap] {
        let krediKartiTuru = HesapTuru.krediKarti.rawValue
        let hesapPredicate = #Predicate<Hesap> { $0.hesapTuruRawValue == krediKartiTuru }
        return try modelContext.fetch(FetchDescriptor(predicate: hesapPredicate))
    }
    
    private func fetchTransactions(for kartHesaplari: [Hesap]) async throws -> [Islem] {
        let kartHesapIDleri = Set(kartHesaplari.map { $0.id })
        let giderTuru = IslemTuru.gider.rawValue
        let baslangic = self.baslangicTarihi
        let bitis = Calendar.current.date(byAdding: .day, value: 1, to: self.bitisTarihi) ?? self.bitisTarihi
        
        let predicate = #Predicate<Islem> { islem in
            islem.tarih >= baslangic &&
            islem.tarih < bitis &&
            islem.turRawValue == giderTuru
        }
        
        let tumIslemler = try modelContext.fetch(FetchDescriptor(predicate: predicate))
        
        // Sadece kredi kartı hesaplarına ait işlemleri filtrele
        return tumIslemler.filter { islem in
            guard let hesapID = islem.hesap?.id else { return false }
            return kartHesapIDleri.contains(hesapID)
        }
    }
    
    private func fetchTransfers(for kartHesaplari: [Hesap]) async throws -> [Transfer] {
        let kartHesapIDleri = Set(kartHesaplari.map { $0.id })
        let baslangic = self.baslangicTarihi
        let bitis = Calendar.current.date(byAdding: .day, value: 1, to: self.bitisTarihi) ?? self.bitisTarihi
        
        let predicate = #Predicate<Transfer> { transfer in
            transfer.tarih >= baslangic && transfer.tarih < bitis
        }
        
        let tumTransferler = try modelContext.fetch(FetchDescriptor(predicate: predicate))
        
        // Kredi kartına yapılan ödemeleri (hedef hesap kredi kartı olanları) filtrele
        return tumTransferler.filter { transfer in
            guard let hedefID = transfer.hedefHesap?.id else { return false }
            return kartHesapIDleri.contains(hedefID)
        }
    }
    
    private func fetchPreviousPeriodData(for kartHesaplari: [Hesap]) async {
        let gunFarki = Calendar.current.dateComponents([.day], from: baslangicTarihi, to: bitisTarihi).day ?? 30
        guard let oncekiBaslangic = Calendar.current.date(byAdding: .day, value: -gunFarki - 1, to: baslangicTarihi),
              let oncekiBitis = Calendar.current.date(byAdding: .day, value: -1, to: baslangicTarihi) else { return }
        
        let kartHesapIDleri = Set(kartHesaplari.map { $0.id })
        let giderTuru = IslemTuru.gider.rawValue
        
        let predicate = #Predicate<Islem> { islem in
            islem.tarih >= oncekiBaslangic &&
            islem.tarih <= oncekiBitis &&
            islem.turRawValue == giderTuru
        }
        
        do {
            let oncekiIslemler = try modelContext.fetch(FetchDescriptor(predicate: predicate))
            let oncekiKartIslemleri = oncekiIslemler.filter { islem in
                guard let hesapID = islem.hesap?.id else { return false }
                return kartHesapIDleri.contains(hesapID)
            }
            
            self.oncekiDonemToplam = oncekiKartIslemleri.reduce(0) { $0 + $1.tutar }
        } catch {
            Logger.log("Önceki dönem verileri çekilirken hata: \(error)", log: Logger.service, type: .error)
        }
    }
    
    // MARK: - Hesaplama Fonksiyonları
    
    private func hesaplamalariYap(kartHesaplari: [Hesap], tumIslemler: [Islem], transferler: [Transfer]) {
        // Genel Özeti Hesapla
        var yeniGenelOzet = KrediKartiGenelOzet()
        yeniGenelOzet.toplamHarcama = tumIslemler.reduce(0) { $0 + $1.tutar }
        yeniGenelOzet.islemSayisi = tumIslemler.count
        yeniGenelOzet.enYuksekHarcama = tumIslemler.max(by: { $0.tutar < $1.tutar })
        yeniGenelOzet.aktifKartSayisi = kartHesaplari.count
        
        // Günlük ortalama
        let gunSayisi = Calendar.current.dateComponents([.day], from: baslangicTarihi, to: bitisTarihi).day ?? 1
        yeniGenelOzet.gunlukOrtalama = yeniGenelOzet.toplamHarcama / Double(max(gunSayisi, 1))
        
        // Önceki döneme göre değişim
        if oncekiDonemToplam > 0 {
            yeniGenelOzet.oncekiDonemeDegisimYuzdesi = ((yeniGenelOzet.toplamHarcama - oncekiDonemToplam) / oncekiDonemToplam) * 100
        }
        
        // En çok kullanılan kart
        let gruplanmisIslemler = Dictionary(grouping: tumIslemler, by: { $0.hesap! })
        if let enCokKullanilan = gruplanmisIslemler.max(by: { $0.value.count < $1.value.count }) {
            yeniGenelOzet.enCokKullanilanKart = enCokKullanilan.key
            let kartHarcamasi = enCokKullanilan.value.reduce(0) { $0 + $1.tutar }
            yeniGenelOzet.enCokKullanilanKartKullanimOrani = (kartHarcamasi / yeniGenelOzet.toplamHarcama) * 100
        }
        
        self.genelOzet = yeniGenelOzet
        
        // Kart Bazında Detayları Hesapla
        var yeniRaporlar: [KartDetayRaporu] = []
        
        for kart in kartHesaplari {
            var kartRaporu = createKartDetayRaporu(
                kart: kart,
                islemler: gruplanmisIslemler[kart] ?? [],
                transferler: transferler.filter { $0.hedefHesap?.id == kart.id }
            )
            
            yeniRaporlar.append(kartRaporu)
        }
        
        self.kartDetayRaporlari = yeniRaporlar.sorted(by: { $0.toplamHarcama > $1.toplamHarcama })
    }
    
    private func createKartDetayRaporu(kart: Hesap, islemler: [Islem], transferler: [Transfer]) -> KartDetayRaporu {
        var kartRaporu = KartDetayRaporu(id: kart.id, hesap: kart)
        
        // Toplam harcama
        kartRaporu.toplamHarcama = islemler.reduce(0) { $0 + $1.tutar }
        kartRaporu.islemSayisi = islemler.count
        
        // Ortalama işlem tutarı
        if islemler.count > 0 {
            kartRaporu.ortalamaIslemTutari = kartRaporu.toplamHarcama / Double(islemler.count)
        }
        
        // Kategori dağılımını hesapla
        kartRaporu.kategoriDagilimi = calculateCategoryDistribution(islemler: islemler)
        
        // Günlük trendi hesapla
        kartRaporu.gunlukHarcamaTrendi = calculateDailyTrend(islemler: islemler)
        
        // En yüksek günlük harcama
        kartRaporu.enYuksekGunlukHarcama = kartRaporu.gunlukHarcamaTrendi.map { $0.tutar }.max()
        
        // Kart limit ve doluluk bilgileri
        if case .krediKarti(let limit, _, _) = kart.detay {
            kartRaporu.kartLimiti = limit
            
            // Güncel borç hesaplama
            let baslangicBorc = abs(kart.baslangicBakiyesi)
            let donemHarcamalari = kartRaporu.toplamHarcama
            let donemOdemeleri = transferler.reduce(0) { $0 + $1.tutar }
            
            kartRaporu.guncelBorc = baslangicBorc + donemHarcamalari - donemOdemeleri
            let guncelBorc = kartRaporu.guncelBorc ?? 0.0
            
            kartRaporu.kullanilabilirLimit = max(0, limit - guncelBorc)
            // Limitin 0'dan büyük olduğunu kontrol ederek sıfıra bölme hatasını da önleyelim.
            if limit > 0 {
                kartRaporu.kartDolulukOrani = (guncelBorc / limit) * 100
            } else {
                kartRaporu.kartDolulukOrani = 0
            }
        }
        
        // Taksitli işlemleri hesapla
        kartRaporu.taksitliIslemler = calculateInstallmentSummary(islemler: islemler)
        
        // Kategori zamanlı dağılım
        kartRaporu.kategoriZamanliDagilim = calculateCategoryTimeDistribution(islemler: islemler)
        
        return kartRaporu
    }
    
    private func calculateCategoryDistribution(islemler: [Islem]) -> [KategoriHarcamasi] {
        // Gruplamayı güvenli bir şekilde yapalım. Anahtar tipi 'Kategori?' olacaktır.
        let kategoriGruplari = Dictionary(grouping: islemler, by: { $0.kategori })
        
        return kategoriGruplari.compactMap { (kategori, islemler) -> KategoriHarcamasi? in
            // 'kategori' artık opsiyonel olduğu için bu kontrol doğru ve gereklidir.
            // Kategorisi olmayan işlemleri (key'i nil olanları) atlar.
            guard let kategori = kategori else { return nil }
            
            let toplam = islemler.reduce(0) { $0 + $1.tutar }
            return KategoriHarcamasi(
                kategori: kategori.isim,
                tutar: toplam,
                renk: kategori.renk,
                localizationKey: kategori.localizationKey,
                ikonAdi: kategori.ikonAdi
            )
        }.sorted(by: { $0.tutar > $1.tutar })
    }
    
    private func calculateDailyTrend(islemler: [Islem]) -> [GunlukHarcama] {
        let calendar = Calendar.current
        let gunlukGruplar = Dictionary(grouping: islemler, by: { calendar.startOfDay(for: $0.tarih) })
        
        var gunlukHarcamalar: [GunlukHarcama] = []
        
        // Dönem içindeki tüm günleri oluştur
        var currentDate = baslangicTarihi
        while currentDate <= bitisTarihi {
            let gunBaslangici = calendar.startOfDay(for: currentDate)
            let gunIslemleri = gunlukGruplar[gunBaslangici] ?? []
            let toplam = gunIslemleri.reduce(0) { $0 + $1.tutar }
            
            gunlukHarcamalar.append(GunlukHarcama(
                gun: gunBaslangici,
                tutar: toplam,
                islemSayisi: gunIslemleri.count
            ))
            
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }
        
        return gunlukHarcamalar.sorted(by: { $0.gun < $1.gun })
    }
    
    private func calculateInstallmentSummary(islemler: [Islem]) -> [TaksitliIslemOzeti] {
        let taksitliIslemler = islemler.filter { $0.taksitliMi }
        
        // Ana taksit ID'sine göre grupla
        let taksitGruplari = Dictionary(grouping: taksitliIslemler) { islem in
            islem.anaTaksitliIslemID ?? UUID()
        }
        
        return taksitGruplari.compactMap { (anaID, taksitler) -> TaksitliIslemOzeti? in
            guard let ilkTaksit = taksitler.first else { return nil }
            
            // Ana ismi çıkar
            let anaIsim = ilkTaksit.isim.replacingOccurrences(
                of: " (\(ilkTaksit.mevcutTaksitNo)/\(ilkTaksit.toplamTaksitSayisi))",
                with: ""
            )
            
            let odenenTaksitSayisi = ilkTaksit.mevcutTaksitNo
            let toplamTaksitSayisi = ilkTaksit.toplamTaksitSayisi
            let kalanTutar = Double(toplamTaksitSayisi - odenenTaksitSayisi) * ilkTaksit.tutar
            
            return TaksitliIslemOzeti(
                id: anaID,
                isim: anaIsim,
                toplamTutar: ilkTaksit.anaIslemTutari,
                aylikTaksitTutari: ilkTaksit.tutar,
                odenenTaksitSayisi: odenenTaksitSayisi,
                toplamTaksitSayisi: toplamTaksitSayisi,
                kalanTutar: kalanTutar
            )
        }.sorted { $0.aylikTaksitTutari > $1.aylikTaksitTutari }
    }
    
    private func calculateCategoryTimeDistribution(islemler: [Islem]) -> [KategoriZamanliDagilim] {
        var dagilimlar: [KategoriZamanliDagilim] = []
        let calendar = Calendar.current
        
        // Önce tarih aralığındaki tüm günleri oluştur
        var gunler: [Date] = []
        var currentDate = baslangicTarihi
        while currentDate <= bitisTarihi {
            gunler.append(calendar.startOfDay(for: currentDate))
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }
        
        // Her kategori için günlük toplamları hesapla
        let kategoriGruplari = Dictionary(grouping: islemler) { $0.kategori }
        
        for (kategori, kategoriIslemleri) in kategoriGruplari {
            guard let kategori = kategori else { continue }
            
            let gunlukGruplar = Dictionary(grouping: kategoriIslemleri) { islem in
                calendar.startOfDay(for: islem.tarih)
            }
            
            // Her gün için veri ekle (0 da olsa)
            for gun in gunler {
                let gunlukToplam = gunlukGruplar[gun]?.reduce(0) { $0 + $1.tutar } ?? 0
                
                // Kategori adını doğrudan kullan, NSLocalizedString kullanma
                dagilimlar.append(KategoriZamanliDagilim(
                    tarih: gun,
                    kategoriAdi: kategori.isim, // Sadece isim kullan
                    tutar: gunlukToplam
                ))
            }
        }
        
        return dagilimlar.sorted { $0.tarih < $1.tarih }
    }
}
