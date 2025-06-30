import SwiftUI
import SwiftData

@MainActor
@Observable
class HaftalikRaporlarViewModel: RaporViewModelProtocol {
    var modelContext: ModelContext
    
    var currentDate: Date = Date() {
        didSet { Task { await fetchData() } }
    }
    
    var ozetVerisi = OzetVerisi()
    var karsilastirmaVerisi = KarsilastirmaVerisi()
    var topGiderKategorileri: [KategoriOzetSatiri] = []
    
    // GÜNCELLEME: Eksik olan özellik eklendi.
    var topGelirKategorileri: [KategoriOzetSatiri] = []
    
    var giderDagilimVerisi: [KategoriOzetSatiri] = []
    var gelirDagilimVerisi: [KategoriOzetSatiri] = []
    var isLoading: Bool = true
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        
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
        self.isLoading = true
        
        let calendar = Calendar.current
        
        guard let anaDonem = calendar.dateInterval(of: .weekOfYear, for: currentDate),
              let oncekiDonemBaslangic = calendar.date(byAdding: .weekOfYear, value: -1, to: anaDonem.start),
              let oncekiDonem = calendar.dateInterval(of: .weekOfYear, for: oncekiDonemBaslangic)
        else {
            self.isLoading = false
            return
        }
        
        let anaDonemIslemleri = await fetchTransactions(for: anaDonem)
        let oncekiDonemIslemleri = await fetchTransactions(for: oncekiDonem)
            
        var yeniOzetVerisi = OzetVerisi()
        let anaDonemGiderleri = anaDonemIslemleri.filter { $0.tur == .gider }
        let anaDonemGelirleri = anaDonemIslemleri.filter { $0.tur == .gelir }
        yeniOzetVerisi.toplamGider = anaDonemGiderleri.reduce(0) { $0 + $1.tutar }
        yeniOzetVerisi.toplamGelir = anaDonemGelirleri.reduce(0) { $0 + $1.tutar }
        yeniOzetVerisi.toplamIslemSayisi = anaDonemIslemleri.count
        yeniOzetVerisi.enYuksekHarcama = anaDonemGiderleri.max(by: { $0.tutar < $1.tutar })
        yeniOzetVerisi.enYuksekGelir = anaDonemGelirleri.max(by: { $0.tutar < $1.tutar })
        let gunSayisi = anaDonem.duration / (60*60*24)
        yeniOzetVerisi.gunlukOrtalamaHarcama = gunSayisi > 0 ? (yeniOzetVerisi.toplamGider / gunSayisi) : 0
        yeniOzetVerisi.gunlukOrtalamaGelir = gunSayisi > 0 ? (yeniOzetVerisi.toplamGelir / gunSayisi) : 0
        self.ozetVerisi = yeniOzetVerisi
        
        var yeniKarsilastirmaVerisi = KarsilastirmaVerisi()
        if !oncekiDonemIslemleri.isEmpty {
            let oncekiDonemGider = oncekiDonemIslemleri.filter { $0.tur == .gider }.reduce(0) { $0 + $1.tutar }
            let oncekiDonemGelir = oncekiDonemIslemleri.filter { $0.tur == .gelir }.reduce(0) { $0 + $1.tutar }
            if oncekiDonemGider > 0 {
                yeniKarsilastirmaVerisi.giderDegisimYuzdesi = ((yeniOzetVerisi.toplamGider - oncekiDonemGider) / oncekiDonemGider) * 100
            }
            yeniKarsilastirmaVerisi.netAkisFarki = yeniOzetVerisi.netAkis - (oncekiDonemGelir - oncekiDonemGider)
        }
        self.karsilastirmaVerisi = yeniKarsilastirmaVerisi
        
        self.topGiderKategorileri = calculateTopCategories(from: anaDonemGiderleri, total: yeniOzetVerisi.toplamGider, limit: 5)
        self.topGelirKategorileri = calculateTopCategories(from: anaDonemGelirleri, total: yeniOzetVerisi.toplamGelir, limit: 5)
        self.giderDagilimVerisi = calculateTopCategories(from: anaDonemGiderleri, total: yeniOzetVerisi.toplamGider, limit: nil)
        self.gelirDagilimVerisi = calculateTopCategories(from: anaDonemGelirleri, total: yeniOzetVerisi.toplamGelir, limit: nil)
        
        self.isLoading = false
    }
    
    private func fetchTransactions(for interval: DateInterval) async -> [Islem] {
        let predicate = #Predicate<Islem> { $0.tarih >= interval.start && $0.tarih < interval.end }
        let descriptor = FetchDescriptor(predicate: predicate)
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            Logger.log("Haftalık Raporlar için işlem verisi çekme hatası: \(error.localizedDescription)", log: Logger.data, type: .error)
            return []
        }
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
