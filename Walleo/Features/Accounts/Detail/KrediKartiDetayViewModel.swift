// Dosya: KrediKartiDetayViewModel.swift

import SwiftUI
import SwiftData

@MainActor
@Observable
class KrediKartiDetayViewModel {
    var modelContext: ModelContext
    var kartHesabi: Hesap
    
    var donemBaslangicTarihi: Date
    var donemBitisTarihi: Date
    var donemIslemleri: [Islem] = []
    var tumTransferler: [Transfer] = []
    
    var toplamHarcama: Double {
        donemIslemleri.reduce(0) { $0 + $1.tutar }
    }
    
    init(modelContext: ModelContext, kartHesabi: Hesap) {
        self.modelContext = modelContext
        self.kartHesabi = kartHesabi
        
        self.donemBaslangicTarihi = Date()
        self.donemBitisTarihi = Date()
        
        self.guncelDonemiHesapla(referansTarih: Date())
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(yenile),
            name: .transactionsDidChange,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(yenile),
            name: .accountDetailsDidChange,
            object: nil
        )
    }
    
    @objc func yenile() {
        self.islemleriGetir()
        self.transferleriGetir()
    }
    
    func transferleriGetir() {
        let kartID = kartHesabi.id
        let predicate = #Predicate<Transfer> { transfer in
            transfer.hedefHesap?.id == kartID // Kredi kartına sadece para gelebilir
        }
        
        let descriptor = FetchDescriptor<Transfer>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.tarih, order: .reverse)]
        )
        
        do {
            let transferler = try modelContext.fetch(descriptor)
            self.tumTransferler = transferler
        } catch {
            Logger.log("Kredi kartı transferleri çekilirken hata: \(error)", log: Logger.data, type: .error)
        }
    }

    func islemleriGetir() {
        let takvim = Calendar.current
        let sorguBitisTarihi = takvim.date(byAdding: .day, value: 1, to: self.donemBitisTarihi)!
        
        let kartID = kartHesabi.id
        let giderTuruRawValue = IslemTuru.gider.rawValue
        
        let baslangic = self.donemBaslangicTarihi
        let bitis = sorguBitisTarihi
        
        let basitPredicate = #Predicate<Islem> { islem in
            islem.tarih >= baslangic &&
            islem.tarih < bitis &&
            islem.turRawValue == giderTuruRawValue
        }
        
        let descriptor = FetchDescriptor<Islem>(
            predicate: basitPredicate,
            sortBy: [SortDescriptor(\.tarih, order: .reverse)]
        )
        
        do {
            let donemGiderleri = try modelContext.fetch(descriptor)
            self.donemIslemleri = donemGiderleri.filter { $0.hesap?.id == kartID }
        } catch {
            Logger.log("Kredi kartı detay işlemleri çekilirken hata: \(error.localizedDescription)", log: Logger.data, type: .error)
            self.donemIslemleri = []
        }
    }
    
    func sonrakiDonem() {
        guard let yeniReferansTarih = Calendar.current.date(byAdding: .day, value: 1, to: self.donemBitisTarihi) else { return }
        guncelDonemiHesapla(referansTarih: yeniReferansTarih)
    }

    func oncekiDonem() {
        guard let yeniReferansTarih = Calendar.current.date(byAdding: .day, value: -1, to: self.donemBaslangicTarihi) else { return }
        guncelDonemiHesapla(referansTarih: yeniReferansTarih)
    }
    
    private func guncelDonemiHesapla(referansTarih: Date) {
        let idToFetch = self.kartHesabi.id
        let hesapPredicate = #Predicate<Hesap> { $0.id == idToFetch }
        
        guard let guncelHesap = try? modelContext.fetch(FetchDescriptor(predicate: hesapPredicate)).first else {
            return
        }
        self.kartHesabi = guncelHesap
        
        guard case .krediKarti(_, let kesimTarihi, _) = kartHesabi.detay else { return }
        
        let takvim = Calendar.current
        let kesimGunu = takvim.component(.day, from: kesimTarihi)
        
        var referansBilesenleri = takvim.dateComponents([.year, .month], from: referansTarih)
        referansBilesenleri.day = kesimGunu
        
        guard let buAyinKesimTarihi = takvim.date(from: referansBilesenleri) else { return }
        
        if referansTarih < buAyinKesimTarihi {
            self.donemBitisTarihi = takvim.date(byAdding: .day, value: -1, to: buAyinKesimTarihi)!
            guard let gecenAyinKesimTarihi = takvim.date(byAdding: .month, value: -1, to: buAyinKesimTarihi) else { return }
            self.donemBaslangicTarihi = gecenAyinKesimTarihi
        } else {
            self.donemBaslangicTarihi = buAyinKesimTarihi
            guard let gelecekAyinKesimTarihi = takvim.date(byAdding: .month, value: 1, to: buAyinKesimTarihi) else { return }
            self.donemBitisTarihi = takvim.date(byAdding: .day, value: -1, to: gelecekAyinKesimTarihi)!
        }
        
        islemleriGetir()
        transferleriGetir()
    }
}
