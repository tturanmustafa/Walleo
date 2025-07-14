//
//  DetayliRaporlarViewModel 2.swift
//  Walleo
//
//  Created by Mustafa Turan on 14.07.2025.
//


import SwiftUI
import SwiftData
import Combine

@MainActor
class DetayliRaporlarViewModel: ObservableObject {
    @Published var baslangicTarihi: Date
    @Published var bitisTarihi: Date
    @Published var yuklemeDurumu: YuklemeDurumu = .bekliyor
    
    // Rapor verileri
    @Published var nakitAkisVerisi: [NakitAkisVerisi] = []
    @Published var kategoriAnalizVerisi: [KategoriAnalizVerisi] = []
    @Published var harcamaAliskanligiVerisi: HarcamaAliskanligiVerisi?
    @Published var hesapHareketVerisi: [HesapHareketVerisi] = []
    @Published var abonelikVerisi: [AbonelikVerisi] = []
    @Published var donemselKarsilastirmaVerisi: DonemselKarsilastirmaVerisi?
    @Published var finansalAnlikVerisi: FinansalAnlikVerisi?
    @Published var butcePerformansiVerisi: [BudgetPerformanceData] = []
    @Published var borcYonetimiVerisi: DebtManagementData?
    
    private var modelContext: ModelContext?
    private let cacheManager = DetayliRaporCacheManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        let calendar = Calendar.current
        let now = Date()
        
        // Mevcut ayın ilk günü
        self.baslangicTarihi = calendar.date(
            from: calendar.dateComponents([.year, .month], from: now)
        ) ?? now
        
        // Mevcut ayın son günü
        if let nextMonth = calendar.date(byAdding: .month, value: 1, to: self.baslangicTarihi) {
            self.bitisTarihi = calendar.date(byAdding: .day, value: -1, to: nextMonth) ?? now
        } else {
            self.bitisTarihi = now
        }
    }
    
    func configure(with modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    func veriYukle(tur: RaporTuru) async {
        guard let modelContext = modelContext else { return }
        
        yuklemeDurumu = .yukleniyor
        
        do {
            switch tur {
            case .nakitAkisi:
                nakitAkisVerisi = try await hesaplaNakitAkisi(modelContext: modelContext)
            case .kategoriRadari:
                kategoriAnalizVerisi = try await hesaplaKategoriAnalizi(modelContext: modelContext)
            case .harcamaAliskanliklari:
                harcamaAliskanligiVerisi = try await hesaplaHarcamaAliskanliklari(modelContext: modelContext)
            case .gelirVeHesaplar:
                hesapHareketVerisi = try await hesaplaHesapHareketleri(modelContext: modelContext)
            case .borcYonetimi:
                borcYonetimiVerisi = try await hesaplaBorcYonetimi(modelContext: modelContext)
            case .butcePerformansi:
                butcePerformansiVerisi = try await hesaplaButcePerformansi(modelContext: modelContext)
            case .abonelikler:
                abonelikVerisi = try await hesaplaAbonelikler(modelContext: modelContext)
            case .donemselKarsilastirma:
                donemselKarsilastirmaVerisi = try await hesaplaDonemselKarsilastirma(modelContext: modelContext)
            case .finansalAnlik:
                finansalAnlikVerisi = try await hesaplaFinansalAnlik(modelContext: modelContext)
            }
            
            yuklemeDurumu = .basarili
        } catch {
            yuklemeDurumu = .hata(error.localizedDescription)
            Logger.log("Rapor yüklenirken hata: \(error)", log: Logger.service, type: .error)
        }
    }
    
    // MARK: - Hesaplama Fonksiyonları
    
    private func hesaplaNakitAkisi(modelContext: ModelContext) async throws -> [NakitAkisVerisi] {
        let cacheKey = "nakitAkisi_\(baslangicTarihi)_\(bitisTarihi)"
        
        return try await cacheManager.getCachedData(for: cacheKey) {
            let predicate = #Predicate<Islem> { islem in
                islem.tarih >= self.baslangicTarihi && islem.tarih <= self.bitisTarihi
            }
            
            let islemler = try modelContext.fetch(FetchDescriptor(predicate: predicate))
            
            // Günlük gruplama
            let calendar = Calendar.current
            var gunlukVeri: [Date: (gelir: Double, gider: Double)] = [:]
            
            for islem in islemler {
                let gun = calendar.startOfDay(for: islem.tarih)
                var gunVerisi = gunlukVeri[gun] ?? (gelir: 0, gider: 0)
                
                if islem.tur == .gelir {
                    gunVerisi.gelir += islem.tutar
                } else {
                    gunVerisi.gider += islem.tutar
                }
                
                gunlukVeri[gun] = gunVerisi
            }
            
            // Başlangıç bakiyesini hesapla
            let baslangicPredicate = #Predicate<Islem> { islem in
                islem.tarih < self.baslangicTarihi
            }
            let oncekiIslemler = try modelContext.fetch(FetchDescriptor(predicate: baslangicPredicate))
            
            var baslangicBakiyesi: Double = 0
            for islem in oncekiIslemler {
                if islem.tur == .gelir {
                    baslangicBakiyesi += islem.tutar
                } else {
                    baslangicBakiyesi -= islem.tutar
                }
            }
            
            // Tüm hesapların başlangıç bakiyelerini ekle
            let hesaplar = try modelContext.fetch(FetchDescriptor<Hesap>())
            for hesap in hesaplar {
                baslangicBakiyesi += hesap.baslangicBakiyesi
            }
            
            // Sıralı veri oluştur
            var sonuc: [NakitAkisVerisi] = []
            var kumulatifBakiye = baslangicBakiyesi
            
            var currentDate = baslangicTarihi
            while currentDate <= bitisTarihi {
                let gunVerisi = gunlukVeri[calendar.startOfDay(for: currentDate)] ?? (gelir: 0, gider: 0)
                let netAkis = gunVerisi.gelir - gunVerisi.gider
                kumulatifBakiye += netAkis
                
                sonuc.append(NakitAkisVerisi(
                    tarih: currentDate,
                    gelir: gunVerisi.gelir,
                    gider: gunVerisi.gider,
                    netAkis: netAkis,
                    kumulatifBakiye: kumulatifBakiye
                ))
                
                currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
            }
            
            return sonuc
        }
    }
    
    private func hesaplaKategoriAnalizi(modelContext: ModelContext) async throws -> [KategoriAnalizVerisi] {
        let predicate = #Predicate<Islem> { islem in
            islem.tarih >= self.baslangicTarihi && islem.tarih <= self.bitisTarihi
        }
        
        let islemler = try modelContext.fetch(FetchDescriptor(predicate: predicate))
        
        // Kategoriye göre grupla
        var kategoriVerileri: [UUID: (kategori: Kategori, tutar: Double, sayi: Int)] = [:]
        
        for islem in islemler {
            guard let kategori = islem.kategori else { continue }
            
            var veri = kategoriVerileri[kategori.id] ?? (kategori: kategori, tutar: 0, sayi: 0)
            veri.tutar += islem.tutar
            veri.sayi += 1
            kategoriVerileri[kategori.id] = veri
        }
        
        let toplamTutar = kategoriVerileri.values.reduce(0) { $0 + $1.tutar }
        
        return kategoriVerileri.values
            .map { veri in
                KategoriAnalizVerisi(
                    kategori: veri.kategori,
                    toplamTutar: veri.tutar,
                    islemSayisi: veri.sayi,
                    ortalamaIslem: veri.sayi > 0 ? veri.tutar / Double(veri.sayi) : 0,
                    yuzde: toplamTutar > 0 ? (veri.tutar / toplamTutar) * 100 : 0
                )
            }
            .sorted { $0.toplamTutar > $1.toplamTutar }
    }
    
    private func hesaplaHarcamaAliskanliklari(modelContext: ModelContext) async throws -> HarcamaAliskanligiVerisi {
        let predicate = #Predicate<Islem> { islem in
            islem.tarih >= self.baslangicTarihi && 
            islem.tarih <= self.bitisTarihi &&
            islem.turRawValue == IslemTuru.gider.rawValue
        }
        
        let harcamalar = try modelContext.fetch(FetchDescriptor(predicate: predicate))
        
        var saatlikDagilim: [Int: Double] = [:]
        var gunlukDagilim: [Int: Double] = [:]
        var odemeYontemiDagilimi: [String: Double] = [:]
        
        let calendar = Calendar.current
        var toplamHarcama: Double = 0
        
        for harcama in harcamalar {
            let saat = calendar.component(.hour, from: harcama.tarih)
            let gun = calendar.component(.weekday, from: harcama.tarih)
            
            saatlikDagilim[saat, default: 0] += harcama.tutar
            gunlukDagilim[gun, default: 0] += harcama.tutar
            
            if let hesap = harcama.hesap {
                let yontem = hesap.detay.odemeYontemiAdi
                odemeYontemiDagilimi[yontem, default: 0] += harcama.tutar
            }
            
            toplamHarcama += harcama.tutar
        }
        
        let ortalamaHarcama = harcamalar.isEmpty ? 0 : toplamHarcama / Double(harcamalar.count)
        let enYogunSaat = saatlikDagilim.max(by: { $0.value < $1.value })?.key ?? 0
        let enYogunGun = gunlukDagilim.max(by: { $0.value < $1.value })?.key ?? 1
        
        return HarcamaAliskanligiVerisi(
            saatlikDagilim: saatlikDagilim,
            gunlukDagilim: gunlukDagilim,
            odemeYontemiDagilimi: odemeYontemiDagilimi,
            ortalamaHarcama: ortalamaHarcama,
            enYogunSaat: enYogunSaat,
            enYogunGun: enYogunGun
        )
    }
    
    private func hesaplaHesapHareketleri(modelContext: ModelContext) async throws -> [HesapHareketVerisi] {
        let hesaplar = try modelContext.fetch(FetchDescriptor<Hesap>())
        var sonuc: [HesapHareketVerisi] = []
        
        for hesap in hesaplar {
            let predicate = #Predicate<Islem> { islem in
                islem.hesap?.id == hesap.id &&
                islem.tarih >= self.baslangicTarihi &&
                islem.tarih <= self.bitisTarihi
            }
            
            let islemler = try modelContext.fetch(FetchDescriptor(predicate: predicate))
            
            var toplamGelir: Double = 0
            var toplamGider: Double = 0
            
            for islem in islemler {
                if islem.tur == .gelir {
                    toplamGelir += islem.tutar
                } else {
                    toplamGider += islem.tutar
                }
            }
            
            let netDegisim = toplamGelir - toplamGider
            let donemSonuBakiye = hesap.baslangicBakiyesi + netDegisim
            
            sonuc.append(HesapHareketVerisi(
                hesap: hesap,
                donemBasiBakiye: hesap.baslangicBakiyesi,
                donemSonuBakiye: donemSonuBakiye,
                toplamGelir: toplamGelir,
                toplamGider: toplamGider,
                islemSayisi: islemler.count,
                netDegisim: netDegisim
            ))
        }
        
        return sonuc.sorted { $0.islemSayisi > $1.islemSayisi }
    }
    
    private func hesaplaBorcYonetimi(modelContext: ModelContext) async throws -> DebtManagementData {
        let kartlar = try modelContext.fetch(FetchDescriptor<Hesap>())
            .filter { if case .krediKarti = $0.detay { return true }; return false }
        
        let krediler = try modelContext.fetch(FetchDescriptor<Hesap>())
            .filter { if case .kredi = $0.detay { return true }; return false }
        
        var kartVerileri: [CreditCardData] = []
        var krediVerileri: [LoanData] = []
        
        // Kredi kartı verileri
        for kart in kartlar {
            if case .krediKarti(let limit, _, _) = kart.detay {
                let predicate = #Predicate<Islem> { islem in
                    islem.hesap?.id == kart.id &&
                    islem.tarih >= self.baslangicTarihi &&
                    islem.tarih <= self.bitisTarihi &&
                    islem.turRawValue == IslemTuru.gider.rawValue
                }
                
                let harcamalar = try modelContext.fetch(FetchDescriptor(predicate: predicate))
                let toplamHarcama = harcamalar.reduce(0) { $0 + $1.tutar }
                let guncelBorc = abs(kart.baslangicBakiyesi) + toplamHarcama
                
                kartVerileri.append(CreditCardData(
                    hesap: kart,
                    limit: limit,
                    guncelBorc: guncelBorc,
                    kullanilabilirLimit: max(0, limit - guncelBorc),
                    donemHarcamasi: toplamHarcama
                ))
            }
        }
        
        // Kredi verileri
        for kredi in krediler {
            if case .kredi(let cekilenTutar, _, _, let taksitSayisi, _, let taksitler) = kredi.detay {
                let odenenTaksitler = taksitler.filter { $0.odendiMi }
                let kalanBorc = taksitler.filter { !$0.odendiMi }
                    .reduce(0) { $0 + $1.taksitTutari }
                
                krediVerileri.append(LoanData(
                    hesap: kredi,
                    toplamTutar: cekilenTutar,
                    odenenTaksitSayisi: odenenTaksitler.count,
                    toplamTaksitSayisi: taksitSayisi,
                    kalanBorc: kalanBorc,
                    sonrakiTaksit: taksitler.first { !$0.odendiMi && $0.odemeTarihi > Date() }
                ))
            }
        }
        
        let toplamKartBorcu = kartVerileri.reduce(0) { $0 + $1.guncelBorc }
        let toplamKrediBorc = krediVerileri.reduce(0) { $0 + $1.kalanBorc }
        
        return DebtManagementData(
            kartVerileri: kartVerileri,
            krediVerileri: krediVerileri,
            toplamBorc: toplamKartBorcu + toplamKrediBorc,
            kartBorcuOrani: toplamKartBorcu / (toplamKartBorcu + toplamKrediBorc)
        )
    }
    
    private func hesaplaButcePerformansi(modelContext: ModelContext) async throws -> [BudgetPerformanceData] {
        let butceler = try modelContext.fetch(FetchDescriptor<Butce>())
            .filter { butce in
                let butceAyi = Calendar.current.dateComponents([.year, .month], from: butce.periyot)
                let baslangicAyi = Calendar.current.dateComponents([.year, .month], from: baslangicTarihi)
                let bitisAyi = Calendar.current.dateComponents([.year, .month], from: bitisTarihi)
                
                return butceAyi.year! >= baslangicAyi.year! &&
                       butceAyi.month! >= baslangicAyi.month! &&
                       butceAyi.year! <= bitisAyi.year! &&
                       butceAyi.month! <= bitisAyi.month!
            }
        
        var sonuc: [BudgetPerformanceData] = []
        
        for butce in butceler {
            guard let monthInterval = Calendar.current.dateInterval(of: .month, for: butce.periyot),
                  let kategoriIDs = butce.kategoriler?.map({ $0.id }) else { continue }
            
            let predicate = #Predicate<Islem> { islem in
                islem.tarih >= monthInterval.start &&
                islem.tarih < monthInterval.end &&
                islem.turRawValue == IslemTuru.gider.rawValue
            }
            
            let tumHarcamalar = try modelContext.fetch(FetchDescriptor(predicate: predicate))
            let ilgiliHarcamalar = tumHarcamalar.filter { islem in
                guard let kategoriID = islem.kategori?.id else { return false }
                return kategoriIDs.contains(kategoriID)
            }
            
            let harcanan = ilgiliHarcamalar.reduce(0) { $0 + $1.tutar }
            let performans = butce.limitTutar > 0 ? (harcanan / butce.limitTutar) * 100 : 0
            
            sonuc.append(BudgetPerformanceData(
                butce: butce,
                harcanan: harcanan,
                limit: butce.limitTutar,
                kalan: butce.limitTutar - harcanan,
                performansYuzdesi: performans,
                durum: performans >= 100 ? .asildi : (performans >= 80 ? .riskli : .iyi)
            ))
        }
        
        return sonuc.sorted { $0.performansYuzdesi > $1.performansYuzdesi }
    }
    
    private func hesaplaAbonelikler(modelContext: ModelContext) async throws -> [AbonelikVerisi] {
        let predicate = #Predicate<Islem> { islem in
            islem.tekrar != TekrarTuru.tekSeferlik &&
            islem.turRawValue == IslemTuru.gider.rawValue
        }
        
        let tekrarliIslemler = try modelContext.fetch(FetchDescriptor(predicate: predicate))
        
        // Benzersiz tekrar ID'lerine göre grupla
        var abonelikGruplari: [UUID: [Islem]] = [:]
        for islem in tekrarliIslemler {
            abonelikGruplari[islem.tekrarID, default: []].append(islem)
        }
        
        var sonuc: [AbonelikVerisi] = []
        
        for (_, grup) in abonelikGruplari {
            guard let ilkIslem = grup.first,
                  let kategori = ilkIslem.kategori else { continue }
            
            // En son işlemi bul
            let sonIslem = grup.max(by: { $0.tarih < $1.tarih }) ?? ilkIslem
            
            // Sonraki ödeme tarihini hesapla
            let calendar = Calendar.current
            var sonrakiOdeme = sonIslem.tarih
            
            switch ilkIslem.tekrar {
            case .herAy:
                sonrakiOdeme = calendar.date(byAdding: .month, value: 1, to: sonIslem.tarih) ?? sonIslem.tarih
            case .her3Ay:
                sonrakiOdeme = calendar.date(byAdding: .month, value: 3, to: sonIslem.tarih) ?? sonIslem.tarih
            case .her6Ay:
                sonrakiOdeme = calendar.date(byAdding: .month, value: 6, to: sonIslem.tarih) ?? sonIslem.tarih
            case .herYil:
                sonrakiOdeme = calendar.date(byAdding: .year, value: 1, to: sonIslem.tarih) ?? sonIslem.tarih
            default:
                continue
            }
            
            // Yıllık maliyeti hesapla
            let yillikMaliyet: Double
            switch ilkIslem.tekrar {
            case .herAy: yillikMaliyet = ilkIslem.tutar * 12
            case .her3Ay: yillikMaliyet = ilkIslem.tutar * 4
            case .her6Ay: yillikMaliyet = ilkIslem.tutar * 2
            case .herYil: yillikMaliyet = ilkIslem.tutar
            default: yillikMaliyet = 0
            }
            
            sonuc.append(AbonelikVerisi(
                isim: ilkIslem.isim,
                kategori: kategori,
                tutar: ilkIslem.tutar,
                tekrarTuru: ilkIslem.tekrar,
                sonrakiOdemeTarihi: sonrakiOdeme,
                yillikMaliyet: yillikMaliyet
            ))
        }
        
        return sonuc.sorted { $0.yillikMaliyet > $1.yillikMaliyet }
    }
    
    private func hesaplaDonemselKarsilastirma(modelContext: ModelContext) async throws -> DonemselKarsilastirmaVerisi {
        let calendar = Calendar.current
        
        // Önceki dönem tarihlerini hesapla
        let gunFarki = calendar.dateComponents([.day], from: baslangicTarihi, to: bitisTarihi).day ?? 30
        guard let oncekiBitis = calendar.date(byAdding: .day, value: -1, to: baslangicTarihi),
              let oncekiBaslangic = calendar.date(byAdding: .day, value: -gunFarki, to: oncekiBitis) else {
            throw NSError(domain: "DateError", code: 0)
        }
        
        // Mevcut dönem verileri
        let mevcutPredicate = #Predicate<Islem> { islem in
            islem.tarih >= self.baslangicTarihi && islem.tarih <= self.bitisTarihi
        }
        let mevcutIslemler = try modelContext.fetch(FetchDescriptor(predicate: mevcutPredicate))
        
        // Önceki dönem verileri
        let oncekiPredicate = #Predicate<Islem> { islem in
            islem.tarih >= oncekiBaslangic && islem.tarih <= oncekiBitis
        }
        let oncekiIslemler = try modelContext.fetch(FetchDescriptor(predicate: oncekiPredicate))
        
        // Dönem verilerini hesapla
        let mevcutDonem = hesaplaDonemVerisi(islemler: mevcutIslemler, baslangic: baslangicTarihi, bitis: bitisTarihi)
        let oncekiDonem = hesaplaDonemVerisi(islemler: oncekiIslemler, baslangic: oncekiBaslangic, bitis: oncekiBitis)
        
        // Kategori değişimlerini hesapla
        var mevcutKategoriler: [UUID: (kategori: Kategori, tutar: Double)] = [:]
        var oncekiKategoriler: [UUID: (kategori: Kategori, tutar: Double)] = [:]
        
        for islem in mevcutIslemler where islem.tur == .gider {
            if let kategori = islem.kategori {
                mevcutKategoriler[kategori.id, default: (kategori, 0)].tutar += islem.tutar
            }
        }
        
        for islem in oncekiIslemler where islem.tur == .gider {
            if let kategori = islem.kategori {
                oncekiKategoriler[kategori.id, default: (kategori, 0)].tutar += islem.tutar
            }
        }
        
        var degisimler: [KategoriDegisim] = []
        let tumKategoriIDs = Set(mevcutKategoriler.keys).union(Set(oncekiKategoriler.keys))
        
        for kategoriID in tumKategoriIDs {
            let eskiVeri = oncekiKategoriler[kategoriID]
            let yeniVeri = mevcutKategoriler[kategoriID]
            
            if let kategori = eskiVeri?.kategori ?? yeniVeri?.kategori {
                let eskiTutar = eskiVeri?.tutar ?? 0
                let yeniTutar = yeniVeri?.tutar ?? 0
                let degisimYuzdesi = eskiTutar > 0 ? ((yeniTutar - eskiTutar) / eskiTutar) * 100 : 0
                
                degisimler.append(KategoriDegisim(
                    kategori: kategori,
                    eskiTutar: eskiTutar,
                    yeniTutar: yeniTutar,
                    degisimYuzdesi: degisimYuzdesi
                ))
            }
        }
        
        return DonemselKarsilastirmaVerisi(
            mevcutDonem: mevcutDonem,
            oncekiDonem: oncekiDonem,
            degisimler: degisimler.sorted { abs($0.degisimYuzdesi) > abs($1.degisimYuzdesi) }
        )
    }
    
    private func hesaplaDonemVerisi(islemler: [Islem], baslangic: Date, bitis: Date) -> DonemVerisi {
        var toplamGelir: Double = 0
        var toplamGider: Double = 0
        
        for islem in islemler {
            if islem.tur == .gelir {
                toplamGelir += islem.tutar
            } else {
                toplamGider += islem.tutar
            }
        }
        
        return DonemVerisi(
            baslangic: baslangic,
            bitis: bitis,
            toplamGelir: toplamGelir,
            toplamGider: toplamGider,
            netAkis: toplamGelir - toplamGider
        )
    }
    
    private func hesaplaFinansalAnlik(modelContext: ModelContext) async throws -> FinansalAnlikVerisi {
        let hesaplar = try modelContext.fetch(FetchDescriptor<Hesap>())
        
        var varliklar: [VarlikDetay] = []
        var borclar: [BorcDetay] = []
        var toplamVarlik: Double = 0
        var toplamBorc: Double = 0
        
        for hesap in hesaplar {
            let predicate = #Predicate<Islem> { islem in
                islem.hesap?.id == hesap.id && islem.tarih <= self.bitisTarihi
            }
            
            let islemler = try modelContext.fetch(FetchDescriptor(predicate: predicate))
            var bakiye = hesap.baslangicBakiyesi
            
            for islem in islemler {
                if islem.tur == .gelir {
                    bakiye += islem.tutar
                } else {
                    bakiye -= islem.tutar
                }
            }
            
            if bakiye >= 0 {
                varliklar.append(VarlikDetay(hesap: hesap, bakiye: bakiye))
                toplamVarlik += bakiye
            } else {
                borclar.append(BorcDetay(hesap: hesap, borc: abs(bakiye)))
                toplamBorc += abs(bakiye)
            }
        }
        
        // Günlük net değer değişimlerini hesapla
        var gunlukDegisimler: [NetDegerDegisim] = []
        var currentDate = baslangicTarihi
        let calendar = Calendar.current
        
        while currentDate <= bitisTarihi {
            let gunPredicate = #Predicate<Islem> { islem in
                islem.tarih <= currentDate
            }
            
            let gunIslemleri = try modelContext.fetch(FetchDescriptor(predicate: gunPredicate))
            var gunNetDeger = hesaplar.reduce(0) { $0 + $1.baslangicBakiyesi }
            
            for islem in gunIslemleri {
                if islem.tur == .gelir {
                    gunNetDeger += islem.tutar
                } else {
                    gunNetDeger -= islem.tutar
                }
            }
            
            gunlukDegisimler.append(NetDegerDegisim(tarih: currentDate, netDeger: gunNetDeger))
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        return FinansalAnlikVerisi(
            toplamVarlik: toplamVarlik,
            toplamBorc: toplamBorc,
            netDeger: toplamVarlik - toplamBorc,
            varliklar: varliklar.sorted { $0.bakiye > $1.bakiye },
            borclar: borclar.sorted { $0.borc > $1.borc },
            gunlukDegisimler: gunlukDegisimler
        )
    }
}

// MARK: - Helper Extensions
extension HesapDetayi {
    var odemeYontemiAdi: String {
        switch self {
        case .cuzdan: return "Nakit"
        case .krediKarti: return "Kredi Kartı"
        case .kredi: return "Kredi"
        }
    }
}

// MARK: - Additional Models
struct BudgetPerformanceData: Identifiable {
    let id = UUID()
    let butce: Butce
    let harcanan: Double
    let limit: Double
    let kalan: Double
    let performansYuzdesi: Double
    let durum: BudgetStatus
    
    enum BudgetStatus {
        case iyi, riskli, asildi
        
        var color: Color {
            switch self {
            case .iyi: return .green
            case .riskli: return .orange
            case .asildi: return .red
            }
        }
    }
}

struct DebtManagementData {
    let kartVerileri: [CreditCardData]
    let krediVerileri: [LoanData]
    let toplamBorc: Double
    let kartBorcuOrani: Double
}

struct CreditCardData: Identifiable {
    let id = UUID()
    let hesap: Hesap
    let limit: Double
    let guncelBorc: Double
    let kullanilabilirLimit: Double
    let donemHarcamasi: Double
}

struct LoanData: Identifiable {
    let id = UUID()
    let hesap: Hesap
    let toplamTutar: Double
    let odenenTaksitSayisi: Int
    let toplamTaksitSayisi: Int
    let kalanBorc: Double
    let sonrakiTaksit: KrediTaksitDetayi?
}