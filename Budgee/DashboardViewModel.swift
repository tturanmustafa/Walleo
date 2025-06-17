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
    }
    
    func fetchData() {
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
        let detaylar = Dictionary(uniqueKeysWithValues: filtrelenmisIslemler.compactMap { islem -> (String, (renk: Color, ikon: String, key: String?))? in
            guard let kategori = islem.kategori else { return nil }
            return (kategori.isim, (kategori.renk, kategori.ikonAdi, kategori.localizationKey))
        })
        
        // ChartPanelView sadece ikon ve renk beklediği için ona uygun bir sözlük daha hazırlıyoruz.
        self.kategoriDetaylari = detaylar.mapValues { ($0.renk, $0.ikon) }
        let gruplanmis = Dictionary(grouping: filtrelenmisIslemler, by: { $0.kategori?.isim ?? "Diğer" })
        let toplamlar = gruplanmis.mapValues { $0.reduce(0) { $0 + $1.tutar } }
        let siraliToplamlar = toplamlar.sorted { $0.value > $1.value }
        
        var yeniPieChartVerisi: [KategoriHarcamasi] = []
        var digerTutar: Double = 0.0
        
        for (kategoriAdi, tutar) in siraliToplamlar {
            // "Diğer" kategorisini sona bırakmak için özel durum yönetimi
            if kategoriAdi == "Diğer" {
                digerTutar += tutar
                continue
            }
            
            // "Diğer" kategorisi için grafikte yer ayırmak amacıyla sınırı 4 yapıyoruz.
            if yeniPieChartVerisi.count < 4 {
                let renk = detaylar[kategoriAdi]?.renk ?? .gray
                let key = detaylar[kategoriAdi]?.key
                yeniPieChartVerisi.append(KategoriHarcamasi(kategori: kategoriAdi, tutar: tutar, renk: renk, localizationKey: key))
            } else {
                digerTutar += tutar
            }
        }
        
        // Eğer "Diğer" kategorisine giren harcama varsa, onu en sona ekliyoruz.
        if digerTutar > 0 {
            yeniPieChartVerisi.append(KategoriHarcamasi(kategori: "Diğer", tutar: digerTutar, renk: .gray, localizationKey: "category.other"))
        }
        
        self.pieChartVerisi = yeniPieChartVerisi
    }
}
