// Dosya: RaporlarViewModel.swift

import SwiftUI
import SwiftData

@MainActor
@Observable
class RaporlarViewModel: RaporViewModelProtocol {
    var modelContext: ModelContext
    
    var currentDate = Date() {
        didSet { Task { await fetchData() } }
    }
    
    // Protokolden gelen ve arayüzün kullandığı özellikler
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
        await MainActor.run {
            self.isLoading = true
            
            let servis = RaporHesaplamaServisi(modelContext: self.modelContext)
            Task { @MainActor in
                let sonuc = await servis.hesapla(periyot: .aylik, tarih: self.currentDate)
                
                // Servisten gelen sonuçları özelliklerimize atıyoruz.
                self.ozetVerisi = sonuc.ozetVerisi
                self.karsilastirmaVerisi = sonuc.karsilastirmaVerisi
                self.topGiderKategorileri = sonuc.topGiderKategorileri
                self.topGelirKategorileri = sonuc.topGelirKategorileri
                self.giderDagilimVerisi = sonuc.giderDagilimVerisi
                self.gelirDagilimVerisi = sonuc.gelirDagilimVerisi
                
                self.isLoading = false
            }
        }
    }
}
