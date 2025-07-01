// Dosya: HaftalikRaporlarViewModel.swift

import SwiftUI
import SwiftData

@MainActor
@Observable
class HaftalikRaporlarViewModel: RaporViewModelProtocol {
    var modelContext: ModelContext
    
    var currentDate: Date = Date() {
        didSet { Task { await fetchData() } }
    }
    
    // Protokolden gelen özellikler
    var ozetVerisi = OzetVerisi()
    var karsilastirmaVerisi = KarsilastirmaVerisi()
    var topGiderKategorileri: [KategoriOzetSatiri] = []
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
        
        let servis = RaporHesaplamaServisi(modelContext: self.modelContext)
        // Tek fark burada: .haftalik parametresini kullanıyoruz
        let sonuc = await servis.hesapla(periyot: .haftalik, tarih: self.currentDate)
        
        // Sonuçları atıyoruz
        self.ozetVerisi = sonuc.ozetVerisi
        self.karsilastirmaVerisi = sonuc.karsilastirmaVerisi
        self.topGiderKategorileri = sonuc.topGiderKategorileri
        self.topGelirKategorileri = sonuc.topGelirKategorileri
        self.giderDagilimVerisi = sonuc.giderDagilimVerisi
        self.gelirDagilimVerisi = sonuc.gelirDagilimVerisi
        
        self.isLoading = false
    }
}
