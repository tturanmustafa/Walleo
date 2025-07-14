//
//  HarcamaIsiHaritasiViewModel.swift
//  Walleo
//
//  Created by Mustafa Turan on 15.07.2025.
//


// >> YENİ DOSYA: Features/ReportsDetailed/HarcamaIsiHaritasiViewModel.swift

import SwiftUI
import SwiftData

@MainActor
@Observable
class HarcamaIsiHaritasiViewModel {
    private var modelContext: ModelContext
    var baslangicTarihi: Date
    var bitisTarihi: Date
    
    // UI'da gösterilecek veriler
    var isiHaritasiVerisi: IsiHaritasiVerisi?
    var saatlikDagilim: [SaatlikDagilimVerisi] = []
    var karsilastirmaVerileri: [HarcamaKarsilastirmaVerisi] = []
    var icgoruler: [HarcamaIcgorusu] = []
    var isLoading = false
    
    // Filtreleme
    var secilenKategoriler: Set<UUID> = []
    var minimumTutar: Double = 0
    
    // appSettings - private kaldırıldı
    let appSettings: AppSettings  // <- private kaldırıldı
    
    init(modelContext: ModelContext, baslangicTarihi: Date, bitisTarihi: Date, appSettings: AppSettings) {
        self.modelContext = modelContext
        self.baslangicTarihi = baslangicTarihi
        self.bitisTarihi = bitisTarihi
        self.appSettings = appSettings
        
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
        Logger.log("Harcama Isı Haritası: Veri çekme başladı. Tarih: \(baslangicTarihi) - \(bitisTarihi)", log: Logger.service)
        
        // 1. İşlemleri çek
        let islemler = await fetchTransactions()
        guard !islemler.isEmpty else {
            Logger.log("Harcama Isı Haritası: İşlem bulunamadı", log: Logger.service)
            isLoading = false
            return
        }
        
        // 2. Gün sayısını hesapla
        let gunSayisi = Calendar.current.dateComponents([.day], from: baslangicTarihi, to: bitisTarihi).day ?? 1
        
        // 3. Zaman dilimlerini oluştur
        let zamanDilimleri = createTimeSlots(gunSayisi: gunSayisi, islemler: islemler)
        
        // 4. Saatlik dağılımı hesapla
        self.saatlikDagilim = calculateHourlyDistribution(islemler: islemler)
        
        // 5. Karşılaştırma verilerini oluştur
        self.karsilastirmaVerileri = createComparisonData(gunSayisi: gunSayisi, islemler: islemler)
        
        // 6. İçgörüleri oluştur
        self.icgoruler = generateInsights(islemler: islemler, gunSayisi: gunSayisi)
        
        // 7. Ana veri modelini oluştur
        self.isiHaritasiVerisi = IsiHaritasiVerisi(
            baslangicTarihi: baslangicTarihi,
            bitisTarihi: bitisTarihi,
            gunSayisi: gunSayisi,
            toplamHarcama: islemler.reduce(0) { $0 + $1.tutar },
            toplamIslemSayisi: islemler.count,
            zamanDilimleri: zamanDilimleri
        )
        
        isLoading = false
        Logger.log("Harcama Isı Haritası: Veri çekme tamamlandı. İşlem sayısı: \(islemler.count)", log: Logger.service)
    }
    
    private func fetchTransactions() async -> [Islem] {
        let giderTuru = IslemTuru.gider.rawValue
        let baslangic = self.baslangicTarihi
        let bitis = Calendar.current.date(byAdding: .day, value: 1, to: self.bitisTarihi) ?? self.bitisTarihi
        
        let predicate = #Predicate<Islem> { islem in
            islem.tarih >= baslangic &&
            islem.tarih < bitis &&
            islem.turRawValue == giderTuru
        }
        
        let descriptor = FetchDescriptor<Islem>(predicate: predicate)
        
        do {
            var islemler = try modelContext.fetch(descriptor)
            
            // Kategori filtresi uygula
            if !secilenKategoriler.isEmpty {
                islemler = islemler.filter { islem in
                    guard let kategoriID = islem.kategori?.id else { return false }
                    return secilenKategoriler.contains(kategoriID)
                }
            }
            
            // Minimum tutar filtresi
            if minimumTutar > 0 {
                islemler = islemler.filter { $0.tutar >= minimumTutar }
            }
            
            return islemler
        } catch {
            Logger.log("Harcama verileri çekilirken hata: \(error)", log: Logger.service, type: .error)
            return []
        }
    }
    
    // Diğer private fonksiyonlar devam edecek...
}
