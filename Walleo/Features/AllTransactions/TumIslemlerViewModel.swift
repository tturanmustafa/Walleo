import SwiftUI
import SwiftData

@Observable
class TumIslemlerViewModel {
    var modelContext: ModelContext
    
    var filtreAyarlari = FiltreAyarlari() {
        didSet { fetchData() }
    }
    
    var islemler: [Islem] = []

    var aktifFiltreSayisi: Int {
        var count = 0
        if filtreAyarlari.tarihAraligi != .hepsi { count += 1 }
        if filtreAyarlari.secilenTurler.count == 1 { count += 1 }
        if !filtreAyarlari.secilenKategoriler.isEmpty { count += 1 }
        return count
    }
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        fetchData()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(fetchData),
            name: .transactionsDidChange,
            object: nil
        )
    }
    
    @objc func fetchData() {
        let calendar = Calendar.current
        var baslangicTarihi: Date?
        var bitisTarihi: Date?
        
        if filtreAyarlari.tarihAraligi != .hepsi {
             switch filtreAyarlari.tarihAraligi {
             case .buHafta:
                 if let interval = calendar.dateInterval(of: .weekOfYear, for: Date()) {
                     baslangicTarihi = interval.start
                     bitisTarihi = interval.end
                 }
            case .buAy:
                if let interval = calendar.dateInterval(of: .month, for: Date()) {
                    baslangicTarihi = interval.start
                    bitisTarihi = interval.end
                }
            case .son3Ay:
                baslangicTarihi = calendar.date(byAdding: .month, value: -3, to: Date())
                bitisTarihi = Date()
            case .son6Ay:
                baslangicTarihi = calendar.date(byAdding: .month, value: -6, to: Date())
                bitisTarihi = Date()
            case .yilBasindanBeri:
                 baslangicTarihi = calendar.date(from: calendar.dateComponents([.year], from: Date()))
                 bitisTarihi = Date()
            case .sonYil:
                baslangicTarihi = calendar.date(byAdding: .year, value: -1, to: Date())
                bitisTarihi = Date()
            case .hepsi:
                break
            }
        }
        
        let turFiltresiAktif = filtreAyarlari.secilenTurler.count == 1
        let secilenTurRawValue = filtreAyarlari.secilenTurler.first?.rawValue
        
        let kategoriFiltresiAktif = !filtreAyarlari.secilenKategoriler.isEmpty
        let secilenKategoriIDleri = filtreAyarlari.secilenKategoriler
        
        let finalPredicate = #Predicate<Islem> { islem in
            (
                (baslangicTarihi == nil || islem.tarih >= baslangicTarihi!) &&
                (bitisTarihi == nil || islem.tarih < bitisTarihi!) &&
                (!turFiltresiAktif || islem.turRawValue == secilenTurRawValue!)
            )
        }
        
        let sortDescriptors: [SortDescriptor<Islem>]
        switch filtreAyarlari.sortOrder {
        case .tarihAzalan: sortDescriptors = [SortDescriptor(\.tarih, order: .reverse)]
        case .tarihArtan: sortDescriptors = [SortDescriptor(\.tarih, order: .forward)]
        case .tutarAzalan: sortDescriptors = [SortDescriptor(\.tutar, order: .reverse)]
        case .tutarArtan: sortDescriptors = [SortDescriptor(\.tutar, order: .forward)]
        }
        
        let descriptor = FetchDescriptor<Islem>(
            predicate: finalPredicate,
            sortBy: sortDescriptors
        )
        
        do {
            var filtrelenmisSonuclar = try modelContext.fetch(descriptor)
            
            if kategoriFiltresiAktif {
                filtrelenmisSonuclar = filtrelenmisSonuclar.filter { islem in
                    guard let kategori = islem.kategori else { return false }
                    return secilenKategoriIDleri.contains(kategori.id)
                }
            }
            
            self.islemler = filtrelenmisSonuclar
            
        } catch {
            print("Filtreli veri çekme hatası (NİHAİ): \(error)")
            islemler = []
        }
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
    func deleteSeri(_ islem: Islem) {
        var userInfo: [String: Any]?
        if let hesapID = islem.hesap?.id {
            userInfo = ["affectedAccountIDs": [hesapID]]
        }
        let tekrarID = islem.tekrarID
        try? modelContext.delete(model: Islem.self, where: #Predicate { $0.tekrarID == tekrarID })
        NotificationCenter.default.post(name: .transactionsDidChange, object: nil, userInfo: userInfo)
    }
}
