import SwiftUI
import SwiftData

@MainActor
@Observable
class TumIslemlerViewModel {
    var modelContext: ModelContext
    var filtreAyarlari = FiltreAyarlari() { didSet { fetchData() } }
    var islemler: [Islem] = []
    var isDeleting = false
    private let modelContainer: ModelContainer

    init(modelContext: ModelContext, baslangicTarihi: Date? = nil) {
        self.modelContext = modelContext
        self.modelContainer = modelContext.container
        
        let calendar = Calendar.current
        
        if let tarih = baslangicTarihi {
            if let ayinAraligi = calendar.dateInterval(of: .month, for: tarih) {
                self.filtreAyarlari.baslangicTarihi = ayinAraligi.start
                self.filtreAyarlari.bitisTarihi = calendar.date(byAdding: .day, value: -1, to: ayinAraligi.end)
                self.filtreAyarlari.tarihAraligi = .ozel
            }
        } else {
            self.filtreAyarlari.tarihAraligi = .buAy
            if let ayinAraligi = self.filtreAyarlari.tarihAraligi.dateInterval() {
                self.filtreAyarlari.baslangicTarihi = ayinAraligi.start
                self.filtreAyarlari.bitisTarihi = calendar.date(byAdding: .day, value: -1, to: ayinAraligi.end)
            }
        }
        
        fetchData()
        NotificationCenter.default.addObserver(self, selector: #selector(fetchData), name: .transactionsDidChange, object: nil)
    }

    @objc func fetchData() {
        let baslangicTarihi = filtreAyarlari.baslangicTarihi
        var sorguBitisTarihi: Date? = nil
        if let bitis = filtreAyarlari.bitisTarihi {
            let bitisinGunu = Calendar.current.startOfDay(for: bitis)
            sorguBitisTarihi = Calendar.current.date(byAdding: .day, value: 1, to: bitisinGunu)
        }
        
        let turFiltresiAktif = filtreAyarlari.secilenTurler.count == 1
        let secilenTurRawValue = filtreAyarlari.secilenTurler.first?.rawValue
        let kategoriFiltresiAktif = !filtreAyarlari.secilenKategoriler.isEmpty
        let secilenKategoriIDleri = filtreAyarlari.secilenKategoriler
        
        let finalPredicate = #Predicate<Islem> { islem in
            (
                (baslangicTarihi == nil || islem.tarih >= baslangicTarihi!) &&
                (sorguBitisTarihi == nil || islem.tarih < sorguBitisTarihi!) &&
                (!turFiltresiAktif || islem.turRawValue == secilenTurRawValue!)
            )
        }
        
        let sortDescriptors: [SortDescriptor<Islem>] = switch filtreAyarlari.sortOrder {
            case .tarihAzalan: [SortDescriptor(\.tarih, order: .reverse)]
            case .tarihArtan: [SortDescriptor(\.tarih, order: .forward)]
            case .tutarAzalan: [SortDescriptor(\.tutar, order: .reverse)]
            case .tutarArtan: [SortDescriptor(\.tutar, order: .forward)]
        }
        
        let descriptor = FetchDescriptor<Islem>(predicate: finalPredicate, sortBy: sortDescriptors)
        
        do {
            var filtrelenmisSonuclar = try modelContext.fetch(descriptor)
            if kategoriFiltresiAktif {
                filtrelenmisSonuclar = filtrelenmisSonuclar.filter { islem in
                    guard let kategori = islem.kategori else { return false }
                    return secilenKategoriIDleri.contains(kategori.id)
                }
            }
            
            let hesapFiltresiAktif = !filtreAyarlari.secilenHesaplar.isEmpty
            let secilenHesapIDleri = filtreAyarlari.secilenHesaplar

            if hesapFiltresiAktif {
                filtrelenmisSonuclar = filtrelenmisSonuclar.filter { islem in
                    guard let hesapID = islem.hesap?.id else { return false }
                    return secilenHesapIDleri.contains(hesapID)
                }
            }
            
            self.islemler = filtrelenmisSonuclar
        } catch {
            Logger.log("Filtreli veri çekme hatası (NİHAİ): \(error.localizedDescription)", log: Logger.data, type: .error)
            islemler = []
        }
    }
    
    func deleteIslem(_ islem: Islem) {
        TransactionService.shared.deleteTransaction(islem, in: modelContext)
        if let index = islemler.firstIndex(where: { $0.id == islem.id }) {
            islemler.remove(at: index)
        }
    }
    
    func deleteSeri(_ islem: Islem) {
        Task {
            isDeleting = true
            await TransactionService.shared.deleteSeriesInBackground(tekrarID: islem.tekrarID, from: modelContainer)
            fetchData()
            isDeleting = false
        }
    }
    
    func deleteTaksitliIslem(_ islem: Islem) {
        TransactionService.shared.deleteTaksitliIslem(islem, in: modelContext)
        // Liste güncelleme
        if let anaID = islem.anaTaksitliIslemID {
            islemler.removeAll { $0.anaTaksitliIslemID == anaID }
        }
    }
}
