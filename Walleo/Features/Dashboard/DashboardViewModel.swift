import SwiftUI
import SwiftData

@MainActor
@Observable
class DashboardViewModel {
    var modelContext: ModelContext
    
    // YENİ: Seri silme işlemi sırasında UI'ı bilgilendirmek için
    var isDeleting = false
    // YENİ: Arka plan servisine vermek için container referansı
    private let modelContainer: ModelContainer
    
    var currentDate = Date() {
        didSet { fetchData() }
    }
    
    var secilenTur: IslemTuru = .gider {
        didSet { fetchData() }
    }
    
    var filtrelenmisIslemler: [Islem] = []
    var toplamTutar: Double = 0
    var pieChartVerisi: [KategoriHarcamasi] = []
    var kategoriDetaylari: [String: (renk: Color, ikon: String)] = [:]

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        // GÜNCELLENDİ: Container'ı saklıyoruz
        self.modelContainer = modelContext.container
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(fetchData),
            name: .transactionsDidChange,
            object: nil
        )
        // DÜZELTME: Yeni sinyal dinleyicisi eklendi
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(fetchData),
            name: .categoriesDidChange, // Yeni sinyali dinliyor
            object: nil
        )
    }
    
    @objc func fetchData() {
        do {
            let calendar = Calendar.current
            guard let monthInterval = calendar.dateInterval(of: .month, for: currentDate) else { return }
            
            let baslangicTarihi = monthInterval.start
            let bitisTarihi = monthInterval.end
            let turRawValue = self.secilenTur.rawValue
            
            let descriptor = FetchDescriptor<Islem>(
                predicate: #Predicate { islem in
                    islem.turRawValue == turRawValue &&
                    islem.tarih >= baslangicTarihi &&
                    islem.tarih < bitisTarihi
                },
                sortBy: [SortDescriptor(\.tarih, order: .reverse)]
            )
            
            let islemler = try modelContext.fetch(descriptor)
            self.filtrelenmisIslemler = islemler
            self.hesaplamalariGuncelle()

        } catch {
            Logger.log("Dashboard veri çekme hatası: \(error.localizedDescription)", log: Logger.data, type: .error)
            self.filtrelenmisIslemler = []
            self.hesaplamalariGuncelle()
        }
    }
    
    private func hesaplamalariGuncelle() {
        toplamTutar = filtrelenmisIslemler.reduce(0) { $0 + $1.tutar }
        
        let detaylar = Dictionary(filtrelenmisIslemler.compactMap { islem -> (String, (renk: Color, ikon: String, key: String?))? in
            guard let kategori = islem.kategori else { return nil }
            return (kategori.isim, (kategori.renk, kategori.ikonAdi, kategori.localizationKey))
        }, uniquingKeysWith: { (ilkBulunan, _) in ilkBulunan })
        
        self.kategoriDetaylari = detaylar.mapValues { ($0.renk, $0.ikon) }
        let gruplanmis = Dictionary(grouping: filtrelenmisIslemler, by: { $0.kategori?.isim ?? "Diğer" })
        let toplamlar = gruplanmis.mapValues { $0.reduce(0) { $0 + $1.tutar } }
        let siraliToplamlar = toplamlar.sorted { $0.value > $1.value }
        
        var yeniPieChartVerisi: [KategoriHarcamasi] = []
        var digerTutar: Double = 0.0
        
        for (kategoriAdi, tutar) in siraliToplamlar {
            if kategoriAdi == "Diğer" {
                digerTutar += tutar
                continue
            }
            
            if yeniPieChartVerisi.count < 4 {
                let renk = detaylar[kategoriAdi]?.renk ?? .gray
                let key = detaylar[kategoriAdi]?.key
                yeniPieChartVerisi.append(KategoriHarcamasi(kategori: kategoriAdi, tutar: tutar, renk: renk, localizationKey: key))
            } else {
                digerTutar += tutar
            }
        }
        
        if digerTutar > 0 {
            yeniPieChartVerisi.append(KategoriHarcamasi(kategori: "Diğer", tutar: digerTutar, renk: .gray, localizationKey: "category.other"))
        }
        
        self.pieChartVerisi = yeniPieChartVerisi
    }
    
    // GÜNCELLENMİŞ FONKSİYON
    func deleteIslem(_ islem: Islem) {
        // Artık `scope` parametresi olmayan doğru fonksiyonu çağırıyoruz.
        TransactionService.shared.deleteTransaction(islem, in: modelContext)
        // Silme sonrası arayüzü yenilemek için veriyi tekrar çekiyoruz.
        fetchData()
    }
    
    
    
    // GÜNCELLENMİŞ FONKSİYON
    func deleteSeri(for islem: Islem) {
        Task {
            isDeleting = true // Silme işlemi başladı
            // Yeni, arka planda çalışan servisi çağırıyoruz.
            await TransactionService.shared.deleteSeriesInBackground(tekrarID: islem.tekrarID, from: modelContainer)
            fetchData() // İşlem bitince veriyi yenile
            isDeleting = false // Silme işlemi bitti
        }
    }
}
