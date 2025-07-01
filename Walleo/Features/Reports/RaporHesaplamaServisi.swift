//
//  RaporHesaplamaServisi.swift
//  Walleo
//
//  Created by Mustafa Turan on 1.07.2025.
//


// Yeni Dosya: RaporHesaplamaServisi.swift

import Foundation
import SwiftData

/// Raporlarla ilgili tüm veri çekme ve hesaplama işlemlerini yürüten merkezi servis.
struct RaporHesaplamaServisi {
    
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    /// Belirtilen periyot ve tarih için tüm rapor verilerini hesaplar.
    func hesapla(periyot: RaporlarView.RaporPeriyodu, tarih: Date) async -> RaporSonucu {
        let calendar = Calendar.current
        
        guard let anaDonem = getAnaDonem(periyot: periyot, tarih: tarih, takvim: calendar) else {
            return .bos()
        }
        let oncekiDonem = getOncekiDonem(periyot: periyot, anaDonem: anaDonem, takvim: calendar)
        
        let anaDonemIslemleri = await fetchTransactions(for: anaDonem)
        let oncekiDonemIslemleri = await fetchTransactions(for: oncekiDonem)
        
        let anaDonemGiderleri = anaDonemIslemleri.filter { $0.tur == .gider }
        let anaDonemGelirleri = anaDonemIslemleri.filter { $0.tur == .gelir }
        
        let ozet = hesaplaOzetVerisi(anaDonemIslemleri: anaDonemIslemleri, anaDonemGiderleri: anaDonemGiderleri, anaDonemGelirleri: anaDonemGelirleri, anaDonem: anaDonem)
        let karsilastirma = hesaplaKarsilastirmaVerisi(mevcutOzet: ozet, oncekiDonemIslemleri: oncekiDonemIslemleri)
        
        let topGiderler = calculateTopCategories(from: anaDonemGiderleri, total: ozet.toplamGider, limit: 5)
        let topGelirler = calculateTopCategories(from: anaDonemGelirleri, total: ozet.toplamGelir, limit: 5)
        let giderDagilim = calculateTopCategories(from: anaDonemGiderleri, total: ozet.toplamGider, limit: nil)
        let gelirDagilim = calculateTopCategories(from: anaDonemGelirleri, total: ozet.toplamGelir, limit: nil)
        
        return RaporSonucu(
            ozetVerisi: ozet,
            karsilastirmaVerisi: karsilastirma,
            topGiderKategorileri: topGiderler,
            topGelirKategorileri: topGelirler,
            giderDagilimVerisi: giderDagilim,
            gelirDagilimVerisi: gelirDagilim
        )
    }
    
    // MARK: - Yardımcı Fonksiyonlar
    
    private func getAnaDonem(periyot: RaporlarView.RaporPeriyodu, tarih: Date, takvim: Calendar) -> DateInterval? {
        switch periyot {
        case .haftalik:
            return takvim.dateInterval(of: .weekOfYear, for: tarih)
        case .aylik:
            return takvim.dateInterval(of: .month, for: tarih)
        }
    }
    
    private func getOncekiDonem(periyot: RaporlarView.RaporPeriyodu, anaDonem: DateInterval, takvim: Calendar) -> DateInterval {
        let oncekiDonemBaslangicTarihi: Date
        switch periyot {
        case .haftalik:
            oncekiDonemBaslangicTarihi = takvim.date(byAdding: .weekOfYear, value: -1, to: anaDonem.start)!
        case .aylik:
            oncekiDonemBaslangicTarihi = takvim.date(byAdding: .month, value: -1, to: anaDonem.start)!
        }
        return getAnaDonem(periyot: periyot, tarih: oncekiDonemBaslangicTarihi, takvim: takvim) ?? anaDonem.previous()
    }
    
    private func fetchTransactions(for interval: DateInterval) async -> [Islem] {
        let predicate = #Predicate<Islem> { $0.tarih >= interval.start && $0.tarih < interval.end }
        let descriptor = FetchDescriptor(predicate: predicate)
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            Logger.log("Raporlar için işlem verisi çekme hatası: \(error.localizedDescription)", log: Logger.data, type: .error)
            return []
        }
    }
    
    private func hesaplaOzetVerisi(anaDonemIslemleri: [Islem], anaDonemGiderleri: [Islem], anaDonemGelirleri: [Islem], anaDonem: DateInterval) -> OzetVerisi {
        var yeniOzetVerisi = OzetVerisi()
        yeniOzetVerisi.toplamGider = anaDonemGiderleri.reduce(0) { $0 + $1.tutar }
        yeniOzetVerisi.toplamGelir = anaDonemGelirleri.reduce(0) { $0 + $1.tutar }
        yeniOzetVerisi.toplamIslemSayisi = anaDonemIslemleri.count
        yeniOzetVerisi.enYuksekHarcama = anaDonemGiderleri.max(by: { $0.tutar < $1.tutar })
        yeniOzetVerisi.enYuksekGelir = anaDonemGelirleri.max(by: { $0.tutar < $1.tutar })
        let gunSayisi = anaDonem.duration / (60*60*24)
        yeniOzetVerisi.gunlukOrtalamaHarcama = gunSayisi > 0 ? (yeniOzetVerisi.toplamGider / gunSayisi) : 0
        yeniOzetVerisi.gunlukOrtalamaGelir = gunSayisi > 0 ? (yeniOzetVerisi.toplamGelir / gunSayisi) : 0
        return yeniOzetVerisi
    }
    
    private func hesaplaKarsilastirmaVerisi(mevcutOzet: OzetVerisi, oncekiDonemIslemleri: [Islem]) -> KarsilastirmaVerisi {
        var yeniKarsilastirmaVerisi = KarsilastirmaVerisi()
        if !oncekiDonemIslemleri.isEmpty {
            let oncekiDonemGider = oncekiDonemIslemleri.filter { $0.tur == .gider }.reduce(0) { $0 + $1.tutar }
            let oncekiDonemGelir = oncekiDonemIslemleri.filter { $0.tur == .gelir }.reduce(0) { $0 + $1.tutar }
            if oncekiDonemGider > 0 {
                yeniKarsilastirmaVerisi.giderDegisimYuzdesi = ((mevcutOzet.toplamGider - oncekiDonemGider) / oncekiDonemGider) * 100
            }
            yeniKarsilastirmaVerisi.netAkisFarki = mevcutOzet.netAkis - (oncekiDonemGelir - oncekiDonemGider)
        }
        return yeniKarsilastirmaVerisi
    }
    
    private func calculateTopCategories(from islemler: [Islem], total: Double, limit: Int?) -> [KategoriOzetSatiri] {
        guard total > 0, !islemler.isEmpty else { return [] }
        let gruplanmis = Dictionary(grouping: islemler, by: { $0.kategori })
        let toplamlar = gruplanmis.mapValues { $0.reduce(0) { $0 + $1.tutar } }
        var siraliKategoriler = toplamlar.sorted { $0.value > $1.value }
        if let limit = limit {
            siraliKategoriler = Array(siraliKategoriler.prefix(limit))
        }
        return siraliKategoriler.compactMap { (kategori, tutar) -> KategoriOzetSatiri? in
            guard let kategori = kategori else { return nil }
            return KategoriOzetSatiri(id: kategori.id, ikonAdi: kategori.ikonAdi, renk: kategori.renk, kategoriAdi: kategori.localizationKey ?? kategori.isim, tutar: tutar, yuzde: (tutar / total) * 100)
        }
    }
}