import SwiftUI
import SwiftData

@MainActor
@Observable
class TumIslemlerViewModel {
    var modelContext: ModelContext
    var filtreAyarlari = FiltreAyarlari()
    var islemler: [Islem] = []
    var isDeleting = false
    var isLoading = false
    
    private let modelContainer: ModelContainer
    
    // YENİ: Cache ve performans optimizasyonu
    private var cachedAllTransactions: [Islem] = []
    private var lastFetchParams: FetchParams?
    
    // YENİ: Batch loading
    private let batchSize = 50
    private var currentBatchIndex = 0
    private var hasMoreData = true
    
    // YENİ: Fetch parametrelerini takip etmek için
    private struct FetchParams: Equatable {
        let baslangicTarihi: Date?
        let bitisTarihi: Date?
        let tarihAraligi: TarihAraligi
        let sortOrder: SortOrder
    }

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
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDataChange),
            name: .transactionsDidChange,
            object: nil
        )
    }
    
    @objc private func handleDataChange(_ notification: Notification) {
        // Veri değişikliği olduğunda (ekleme, silme, güncelleme fark etmeksizin)
        // en güvenli ve tutarlı yöntem, yerel cache'i temizleyip veriyi
        // veritabanından yeniden çekmektir.
        // Bu, tüm filtrelerin korunmasını ve listenin doğru görüntülenmesini sağlar.
        
        // 1. Mevcut önbelleği temizle
        cachedAllTransactions.removeAll() //
        
        // 2. Veriyi yeniden yükle
        fetchData() //
    }

    @objc func fetchData() {
        // YENİ: Loading durumunu kontrol et
        guard !isLoading else { return }
        
        Task {
            await performFetch()
        }
    }
    
    private func performFetch() async {
        isLoading = true
        defer { isLoading = false }
        
        let currentParams = FetchParams(
            baslangicTarihi: filtreAyarlari.baslangicTarihi,
            bitisTarihi: filtreAyarlari.bitisTarihi,
            tarihAraligi: filtreAyarlari.tarihAraligi,
            sortOrder: filtreAyarlari.sortOrder
        )
        
        // YENİ: Eğer parametreler değişmediyse ve cache varsa, sadece filtrele
        if currentParams == lastFetchParams && !cachedAllTransactions.isEmpty {
            applyFiltersToCache()
            return
        }
        
        lastFetchParams = currentParams
        
        // Tarih hesaplamaları
        let baslangicTarihi = filtreAyarlari.baslangicTarihi
        var sorguBitisTarihi: Date? = nil
        if let bitis = filtreAyarlari.bitisTarihi {
            let bitisinGunu = Calendar.current.startOfDay(for: bitis)
            sorguBitisTarihi = Calendar.current.date(byAdding: .day, value: 1, to: bitisinGunu)
        }
        
        // Tür filtresi
        let turFiltresiAktif = filtreAyarlari.secilenTurler.count == 1
        let secilenTurRawValue = filtreAyarlari.secilenTurler.first?.rawValue
        
        // YENİ: Optimize edilmiş predicate
        let finalPredicate = #Predicate<Islem> { islem in
            (baslangicTarihi == nil || islem.tarih >= baslangicTarihi!) &&
            (sorguBitisTarihi == nil || islem.tarih < sorguBitisTarihi!) &&
            (!turFiltresiAktif || islem.turRawValue == secilenTurRawValue!)
        }
        
        let sortDescriptors: [SortDescriptor<Islem>] = switch filtreAyarlari.sortOrder {
            case .tarihAzalan: [SortDescriptor(\.tarih, order: .reverse)]
            case .tarihArtan: [SortDescriptor(\.tarih, order: .forward)]
            case .tutarAzalan: [SortDescriptor(\.tutar, order: .reverse)]
            case .tutarArtan: [SortDescriptor(\.tutar, order: .forward)]
        }
        
        let descriptor = FetchDescriptor<Islem>(
            predicate: finalPredicate,
            sortBy: sortDescriptors
        )
        
        do {
            // Tüm veriyi bir kere çek ve cache'le
            cachedAllTransactions = try modelContext.fetch(descriptor)
            
            // Filtreleri uygula
            applyFiltersToCache()
            
        } catch {
            Logger.log("Filtreli veri çekme hatası: \(error.localizedDescription)", log: Logger.data, type: .error)
            islemler = []
        }
    }
    
    // YENİ: Cache'lenmiş veriye filtreleri uygula
    private func applyFiltersToCache() {
        var filtrelenmisSonuclar = cachedAllTransactions
        
        // Kategori filtresi
        if !filtreAyarlari.secilenKategoriler.isEmpty {
            let secilenKategoriIDleri = filtreAyarlari.secilenKategoriler
            filtrelenmisSonuclar = filtrelenmisSonuclar.filter { islem in
                guard let kategoriID = islem.kategori?.id else { return false }
                return secilenKategoriIDleri.contains(kategoriID)
            }
        }
        
        // Hesap filtresi
        if !filtreAyarlari.secilenHesaplar.isEmpty {
            let secilenHesapIDleri = filtreAyarlari.secilenHesaplar
            filtrelenmisSonuclar = filtrelenmisSonuclar.filter { islem in
                guard let hesapID = islem.hesap?.id else { return false }
                return secilenHesapIDleri.contains(hesapID)
            }
        }
        
        // YENİ: Batch loading simülasyonu (performans için)
        // İlk yüklemede tüm veriyi göster, sonraki filtrelemede animasyonlu geçiş için
        self.islemler = filtrelenmisSonuclar
    }
    
    // YENİ: Filtre değişikliklerini bildir
    func onFilterChanged() {
        // Cache'i invalidate etmeden sadece filtreleri uygula
        if !cachedAllTransactions.isEmpty {
            applyFiltersToCache()
        } else {
            fetchData()
        }
    }
    
    // YENİ: Cache'i temizle ve yeniden fetch et
    func invalidateCacheAndFetch() {
        cachedAllTransactions.removeAll()
        fetchData()
    }
    
    func deleteIslem(_ islem: Islem) {
        TransactionService.shared.deleteTransaction(islem, in: modelContext)
        
        // YENİ: Optimistik güncelleme
        if let index = islemler.firstIndex(where: { $0.id == islem.id }) {
            // withAnimation zaten MainActor context'inde çalışıyor
            islemler.remove(at: index)
        }
        
        // Cache'den de sil
        cachedAllTransactions.removeAll { $0.id == islem.id }
    }
    
    func deleteSeri(_ islem: Islem) {
        Task {
            isDeleting = true
            await TransactionService.shared.deleteSeriesInBackground(
                tekrarID: islem.tekrarID,
                from: modelContainer
            )
            
            // YENİ: Seri silindikten sonra cache'i temizle ve yeniden yükle
            cachedAllTransactions.removeAll()
            await performFetch()
            
            isDeleting = false
        }
    }
    
    func deleteTaksitliIslem(_ islem: Islem) {
        TransactionService.shared.deleteTaksitliIslem(islem, in: modelContext)
        
        // YENİ: Optimistik güncelleme
        if let anaID = islem.anaTaksitliIslemID {
            // withAnimation zaten MainActor context'inde çalışıyor
            islemler.removeAll { $0.anaTaksitliIslemID == anaID }
            cachedAllTransactions.removeAll { $0.anaTaksitliIslemID == anaID }
        }
    }
}
