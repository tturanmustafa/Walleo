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
    
    // YENİ: Taksitli işlemler için
    var taksitliIslemGruplari: [TaksitliIslemGrubu] = []
    
    var toplamHarcama: Double {
        donemIslemleri.reduce(0) { $0 + $1.tutar }
    }
    
    // YENİ: Taksitli işlem grubu yapısı
    struct TaksitliIslemGrubu: Identifiable {
        let id: UUID
        let anaIsim: String
        let toplamTutar: Double
        let taksitler: [Islem]
        let tamamlananTaksitSayisi: Int
        
        var aciklamaMetni: String {
            let tamamlanan = taksitler.filter { $0.tarih <= Date() }.count
            return "\(formatCurrency(amount: toplamTutar, currencyCode: AppSettings().currencyCode, localeIdentifier: AppSettings().languageCode)) - \(tamamlanan)/\(taksitler.count) taksit"
        }
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
        let takvim = Calendar.current
        let sorguBitisTarihi = takvim.date(byAdding: .day, value: 1, to: self.donemBitisTarihi)!
        let baslangic = self.donemBaslangicTarihi
        let bitis = sorguBitisTarihi
        
        // Predicate'e tarih kontrolü ekliyoruz.
        let predicate = #Predicate<Transfer> { transfer in
            transfer.hedefHesap?.id == kartID &&
            transfer.tarih >= baslangic && // Sadece bu döneme ait transferleri al
            transfer.tarih < bitis        // Sadece bu döneme ait transferleri al
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
            let kartaAitIslemler = donemGiderleri.filter { $0.hesap?.id == kartID }
            
            // Normal işlemler (taksitli olmayanlar)
            self.donemIslemleri = kartaAitIslemler.filter { !$0.taksitliMi }
            
            // Taksitli işlemleri grupla
            grupTaksitliIslemler(from: kartaAitIslemler.filter { $0.taksitliMi })
            
        } catch {
            Logger.log("Kredi kartı detay işlemleri çekilirken hata: \(error.localizedDescription)", log: Logger.data, type: .error)
            self.donemIslemleri = []
            self.taksitliIslemGruplari = []
        }
    }
    
    // YENİ: Taksitli işlemleri gruplama
    private func grupTaksitliIslemler(from taksitler: [Islem]) {
        let gruplar = Dictionary(grouping: taksitler) { $0.anaTaksitliIslemID ?? UUID() }
        
        self.taksitliIslemGruplari = gruplar.compactMap { (anaID, taksitler) in
            guard let ilkTaksit = taksitler.first else { return nil }
            
            // Ana ismi çıkar (örn: "Araba (1/6)" -> "Araba")
            let anaIsim = ilkTaksit.isim.replacingOccurrences(
                of: " (\(ilkTaksit.mevcutTaksitNo)/\(ilkTaksit.toplamTaksitSayisi))",
                with: ""
            )
            
            // Taksitleri sırala
            let siraliTaksitler = taksitler.sorted { $0.mevcutTaksitNo < $1.mevcutTaksitNo }
            
            return TaksitliIslemGrubu(
                id: anaID,
                anaIsim: anaIsim,
                toplamTutar: ilkTaksit.anaIslemTutari,
                taksitler: siraliTaksitler,
                tamamlananTaksitSayisi: taksitler.filter { $0.tarih <= Date() }.count
            )
        }.sorted { $0.anaIsim < $1.anaIsim }
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
