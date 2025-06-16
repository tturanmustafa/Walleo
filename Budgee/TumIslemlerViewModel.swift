import SwiftUI
import SwiftData

@Observable
class TumIslemlerViewModel {
    var modelContext: ModelContext
    
    var filtreAyarlari = FiltreAyarlari() {
        didSet { fetchData() }
    }
    
    var islemler: [Islem] = []
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        fetchData()
    }
    
    func fetchData() {
        let calendar = Calendar.current
        var baslangicTarihi: Date?
        var bitisTarihi: Date?
        
        if filtreAyarlari.tarihAraligi != .hepsi {
             switch filtreAyarlari.tarihAraligi {
            case .buAy:
                if let interval = calendar.dateInterval(of: .month, for: Date()) {
                    baslangicTarihi = interval.start
                    bitisTarihi = interval.end
                }
            case .son3Ay: baslangicTarihi = calendar.date(byAdding: .month, value: -3, to: Date())
            case .son6Ay: baslangicTarihi = calendar.date(byAdding: .month, value: -6, to: Date())
            case .buYil: baslangicTarihi = calendar.date(from: calendar.dateComponents([.year], from: Date()))
            case .hepsi: break
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
                // DEĞİŞİKLİK: Sorguyu artık doğrudan veritabanındaki 'turRawValue' alanına atıyoruz.
                (!turFiltresiAktif || islem.turRawValue == secilenTurRawValue!) &&
                (!kategoriFiltresiAktif || (islem.kategori != nil && secilenKategoriIDleri.contains(islem.kategori!.id)))
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
            islemler = try modelContext.fetch(descriptor)
        } catch {
            print("Filtreli veri çekme hatası (NİHAİ): \(error)")
            islemler = []
        }
    }
    
    func deleteIslem(_ islem: Islem) {
        modelContext.delete(islem)
        fetchData()
    }
    
    func deleteSeri(_ islem: Islem) {
        let tekrarID = islem.tekrarID
        try? modelContext.delete(model: Islem.self, where: #Predicate { $0.tekrarID == tekrarID })
        fetchData()
    }
}
