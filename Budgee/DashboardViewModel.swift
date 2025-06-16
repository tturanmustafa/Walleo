import SwiftUI
import SwiftData

@MainActor
@Observable
class DashboardViewModel {
    var modelContext: ModelContext
    
    var secilenTur: IslemTuru = .gider {
        didSet { fetchData() }
    }
    var currentDate = Date() {
        didSet { fetchData() }
    }
    
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
                    // DEĞİŞİKLİK: Sorguyu artık doğrudan veritabanındaki 'turRawValue' alanına atıyoruz.
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
            print("Dashboard veri çekme hatası (NİHAİ): \(error)")
        }
    }
    
    // hesaplamalariGuncelle() fonksiyonu 'islem.tur' kullandığı için
    // Islem modeline eklediğimiz yardımcı değişken sayesinde HİÇBİR DEĞİŞİKLİK GEREKTİRMEZ.
    private func hesaplamalariGuncelle() {
        toplamTutar = filtrelenmisIslemler.reduce(0) { $0 + $1.tutar }
        
        let detaylar = Dictionary(uniqueKeysWithValues: filtrelenmisIslemler.compactMap { islem -> (String, (renk: Color, ikon: String))? in
            guard let kategori = islem.kategori else { return nil }
            return (kategori.isim, (kategori.renk, kategori.ikonAdi))
        })
        self.kategoriDetaylari = detaylar
        
        let gruplanmis = Dictionary(grouping: filtrelenmisIslemler, by: { $0.kategori?.isim ?? "Diğer" })
        let toplamlar = gruplanmis.mapValues { $0.reduce(0) { $0 + $1.tutar } }
        let siraliToplamlar = toplamlar.sorted { $0.value > $1.value }
        
        var yeniPieChartVerisi: [KategoriHarcamasi] = []
        var digerTutar: Double = 0.0
        
        for (kategoriAdi, tutar) in siraliToplamlar {
            if yeniPieChartVerisi.count < 5 {
                let renk = detaylar[kategoriAdi]?.renk ?? .gray
                yeniPieChartVerisi.append(KategoriHarcamasi(kategori: kategoriAdi, tutar: tutar, renk: renk))
            } else {
                digerTutar += tutar
            }
        }
        if digerTutar > 0 { yeniPieChartVerisi.append(KategoriHarcamasi(kategori: "Diğer", tutar: digerTutar, renk: .gray)) }
        self.pieChartVerisi = yeniPieChartVerisi
    }
}
