import SwiftUI
import SwiftData

@MainActor
@Observable
class DashboardViewModel {
    var modelContext: ModelContext
    
    // View'ın durumunu tutan değişkenler
    var secilenTur: IslemTuru = .gider {
        didSet { fetchData() }
    }
    var currentDate = Date() {
        didSet { fetchData() }
    }
    
    // View'a sunulacak olan, işlenmiş veriler
    var filtrelenmisIslemler: [Islem] = []
    var toplamTutar: Double = 0
    var pieChartVerisi: [KategoriHarcamasi] = []
    var kategoriDetaylari: [String: (renk: Color, ikon: String)] = [:]

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        
        // "yeniIslemEklendi" bildirimini dinlemek için gözlemci ekleniyor.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(fetchData), // Bildirim gelince bu fonksiyonu çalıştır
            name: .yeniIslemEklendi,
            object: nil
        )
    }
    
    // fetchData fonksiyonu artık @objc olmalı çünkü selector olarak kullanılıyor.
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
            print("Dashboard veri çekme hatası: \(error)")
            self.filtrelenmisIslemler = []
            self.hesaplamalariGuncelle()
        }
    }
    
    private func hesaplamalariGuncelle() {
        toplamTutar = filtrelenmisIslemler.reduce(0) { $0 + $1.tutar }
        
        // Bu sözlük artık ikon, renk ve çeviri anahtarını bir arada tutuyor.
        let detaylar = Dictionary(filtrelenmisIslemler.compactMap { islem -> (String, (renk: Color, ikon: String, key: String?))? in
            guard let kategori = islem.kategori else { return nil }
            return (kategori.isim, (kategori.renk, kategori.ikonAdi, kategori.localizationKey))
        }, uniquingKeysWith: { (ilkBulunan, _) in ilkBulunan })
        
        // ChartPanelView sadece ikon ve renk beklediği için ona uygun bir sözlük daha hazırlıyoruz.
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
    
    /// Tek bir işlemi siler ve ardından listeyi yeniler.
    func deleteIslem(_ islem: Islem) {
        modelContext.delete(islem)
        fetchData()
    }
    
    /// Tekrarlayan bir işlem serisinin tamamını siler ve listeyi yeniler.
    func deleteSeri(for islem: Islem) {
        let tekrarID = islem.tekrarID
        guard tekrarID != UUID() else {
            deleteIslem(islem)
            return
        }
        
        try? modelContext.delete(model: Islem.self, where: #Predicate { $0.tekrarID == tekrarID })
        fetchData()
    }
}
