//
//  KrediKartiRaporuViewModel.swift
//  Walleo
//
//  Created by Mustafa Turan on 14.07.2025.
//


// >> YENİ DOSYA: Features/Reports/KrediKartiRaporuViewModel.swift

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
        
        let sorguBitisTarihi = Calendar.current.date(byAdding: .day, value: 1, to: bitisTarihi) ?? bitisTarihi

        let krediKartiTuru = HesapTuru.krediKarti.rawValue
        let hesapPredicate = #Predicate<Hesap> { $0.hesapTuruRawValue == krediKartiTuru }
        guard let kartHesaplari = try? modelContext.fetch(FetchDescriptor(predicate: hesapPredicate)) else {
            Logger.log("KrediKarti Raporu: Hiç kredi kartı hesabı bulunamadı", log: Logger.service, type: .error)
            isLoading = false
            return
        }
        
        Logger.log("KrediKarti Raporu: \(kartHesaplari.count) adet kart bulundu", log: Logger.service)
        let kartHesapIDleri = Set(kartHesaplari.map { $0.id }) // Daha hızlı arama için Set'e çeviriyoruz.
        
        // --- DÜZELTME BAŞLIYOR ---

        // 1. ADIM: Predicate'i basitleştir. Sadece tarih ve türe göre filtrele.
        let giderTuru = IslemTuru.gider.rawValue
        let baslangic = self.baslangicTarihi
        let bitis = sorguBitisTarihi

        let basitIslemPredicate = #Predicate<Islem> { islem in
            islem.tarih >= baslangic &&
            islem.tarih < bitis &&
            islem.turRawValue == giderTuru
        }
        
        do {
            // 2. ADIM: Basit predicate ile veritabanından işlemleri çek.
            let donemIslemleri = try modelContext.fetch(FetchDescriptor(predicate: basitIslemPredicate))
            
            // 3. ADIM: Çekilen sonuçları hafızada kart ID'lerine göre yeniden filtrele.
            // Bu, derleyici hatasını %100 çözer.
            let tumIslemler = donemIslemleri.filter { islem in
                guard let hesapID = islem.hesap?.id else { return false }
                return kartHesapIDleri.contains(hesapID)
            }
        
            // 4. ADIM: Verileri işle ve raporları oluştur. (Bu kısım aynı kalıyor)
            Logger.log("KrediKarti Raporu: \(tumIslemler.count) adet işlem bulundu", log: Logger.service)
            hesaplamalariYap(kartHesaplari: kartHesaplari, tumIslemler: tumIslemler)
            
        } catch {
            Logger.log("Detaylı Raporlar için işlem verisi çekilirken hata: \(error.localizedDescription)", log: Logger.service, type: .error)
        }
        
        // --- DÜZELTME BİTİYOR ---
        
        isLoading = false
        Logger.log("KrediKarti Raporu: Veri çekme tamamlandı. Rapor sayısı: \(kartDetayRaporlari.count)", log: Logger.service)
    }
    
    private func hesaplamalariYap(kartHesaplari: [Hesap], tumIslemler: [Islem]) {
        // Genel Özeti Hesapla
        var yeniGenelOzet = KrediKartiGenelOzet()
        yeniGenelOzet.toplamHarcama = tumIslemler.reduce(0) { $0 + $1.tutar }
        yeniGenelOzet.islemSayisi = tumIslemler.count
        yeniGenelOzet.enYuksekHarcama = tumIslemler.max(by: { $0.tutar < $1.tutar })
        
        let gruplanmisIslemler = Dictionary(grouping: tumIslemler, by: { $0.hesap! })
        if let enCokKullanilan = gruplanmisIslemler.max(by: { $0.value.count < $1.value.count }) {
            yeniGenelOzet.enCokKullanilanKart = enCokKullanilan.key
        }
        self.genelOzet = yeniGenelOzet
        
        // Kart Bazında Detayları Hesapla
        var yeniRaporlar: [KartDetayRaporu] = []
        for kart in kartHesaplari {
            let kartaAitIslemler = gruplanmisIslemler[kart] ?? []
            if kartaAitIslemler.isEmpty { continue }
            
            var kartRaporu = KartDetayRaporu(id: kart.id, hesap: kart)
            kartRaporu.toplamHarcama = kartaAitIslemler.reduce(0) { $0 + $1.tutar }
            
            // Kategori dağılımını hesapla (Pasta Grafik için)
            let kategoriGruplari = Dictionary(grouping: kartaAitIslemler, by: { $0.kategori! })
            kartRaporu.kategoriDagilimi = kategoriGruplari.map { (kategori, islemler) in
                let toplam = islemler.reduce(0) { $0 + $1.tutar }
                // --- GÜNCELLENEN SATIR ---
                return KategoriHarcamasi(kategori: kategori.isim, tutar: toplam, renk: kategori.renk, localizationKey: kategori.localizationKey, ikonAdi: kategori.ikonAdi)
            }.sorted(by: { $0.tutar > $1.tutar })
            
            // Günlük trendi hesapla (Çizgi Grafik için)
            let gunlukGruplar = Dictionary(grouping: kartaAitIslemler, by: { Calendar.current.startOfDay(for: $0.tarih) })
            kartRaporu.gunlukHarcamaTrendi = gunlukGruplar.map { (gun, islemler) in
                let toplam = islemler.reduce(0) { $0 + $1.tutar }
                return GunlukHarcama(gun: gun, tutar: toplam)
            }.sorted(by: { $0.gun < $1.gun })
            
            yeniRaporlar.append(kartRaporu)
        }
        self.kartDetayRaporlari = yeniRaporlar.sorted(by: { $0.toplamHarcama > $1.toplamHarcama })
    }
}
