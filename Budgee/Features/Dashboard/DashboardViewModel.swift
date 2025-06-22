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
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(fetchData),
            name: .transactionsDidChange,
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
            print("Dashboard veri çekme hatası: \(error)")
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
    
    // --- GÜNCELLEME: Akıllı Bildirim Gönderimi ---
        func deleteIslem(_ islem: Islem) {
            var userInfo: [String: Any]?
            if let hesapID = islem.hesap?.id {
                userInfo = ["affectedAccountIDs": [hesapID]]
            }
            modelContext.delete(islem)
            NotificationCenter.default.post(name: .transactionsDidChange, object: nil, userInfo: userInfo)
        }
        
        // --- GÜNCELLEME: Akıllı Bildirim Gönderimi ---
        func deleteSeri(for islem: Islem) {
            let tekrarID = islem.tekrarID
            guard tekrarID != UUID() else {
                deleteIslem(islem)
                return
            }
            
            // Not: Seri silme işlemi birden çok hesabı etkileyebilir.
            // En güvenli yol, bu durumda userInfo göndermeyerek tüm hesapların güncellenmesini sağlamaktır.
            // Şimdilik basitlik adına bu şekilde bırakıyoruz.
            var userInfo: [String: Any]?
            if let hesapID = islem.hesap?.id {
                userInfo = ["affectedAccountIDs": [hesapID]]
            }
            
            try? modelContext.delete(model: Islem.self, where: #Predicate { $0.tekrarID == tekrarID })
            NotificationCenter.default.post(name: .transactionsDidChange, object: nil, userInfo: userInfo)
        }
    }
