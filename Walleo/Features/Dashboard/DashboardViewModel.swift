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
        didSet {
            // YENİ: Sadece ay değiştiğinde veriyi yenile
            if !Calendar.current.isDate(oldValue, equalTo: currentDate, toGranularity: .month) {
                invalidateCache()
                fetchData()
            }
        }
    }
    
    var secilenTur: IslemTuru = .gider {
        didSet {
            if oldValue != secilenTur {
                fetchData()
            }
        }
    }
    
    var filtrelenmisIslemler: [Islem] = []
    var toplamTutar: Double = 0
    var pieChartVerisi: [KategoriHarcamasi] = []
    var kategoriDetaylari: [String: (renk: Color, ikon: String)] = [:]
    
    // YENİ: Cache mekanizması
    private var cachedMonthData: [IslemTuru: [Islem]] = [:]
    private var lastFetchDate: Date?
    private var isDataStale = true

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        // GÜNCELLENDİ: Container'ı saklıyoruz
        self.modelContainer = modelContext.container
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDataChange),
            name: .transactionsDidChange,
            object: nil
        )
        // DÜZELTME: Yeni sinyal dinleyicisi eklendi
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCategoryChange),
            name: .categoriesDidChange,
            object: nil
        )
    }
    
    // YENİ: Akıllı güncelleme mekanizması
    @objc private func handleDataChange(_ notification: Notification) {
        // İşlem değişikliği olduğunda cache'i temizle
        invalidateCache()
        
        // Payload'dan etkilenen hesapları ve kategorileri al
        if let payload = notification.userInfo?["payload"] as? TransactionChangePayload {
            // Sadece mevcut görünümdeki veriyi etkileyen değişikliklerde güncelle
            if shouldRefreshView(for: payload) {
                fetchData()
            }
        } else {
            // Payload yoksa güvenli tarafta kalıp güncelle
            fetchData()
        }
    }
    
    @objc private func handleCategoryChange() {
        // Kategori değişikliği chart'ı etkileyeceği için cache'i temizle
        invalidateCache()
        fetchData()
    }
    
    private func shouldRefreshView(for payload: TransactionChangePayload) -> Bool {
        // Mevcut ay ve tür ile ilgili değişiklik mi kontrol et
        // Bu daha detaylı implemente edilebilir
        return true // Şimdilik basit tutalım
    }
    
    func invalidateCache() {
        cachedMonthData.removeAll()
        isDataStale = true
    }
    
    @objc func fetchData() {
        // YENİ: Cache kontrolü - sadece veri stale değilse cache kullan
        if !isDataStale &&
           Calendar.current.isDate(lastFetchDate ?? Date(), equalTo: currentDate, toGranularity: .month) &&
           cachedMonthData[secilenTur] != nil {
            // Cache'den kullan
            if let cached = cachedMonthData[secilenTur] {
                self.filtrelenmisIslemler = cached
                self.hesaplamalariGuncelle()
                return
            }
        }
        
        do {
            let calendar = Calendar.current
            guard let monthInterval = calendar.dateInterval(of: .month, for: currentDate) else { return }
            
            let baslangicTarihi = monthInterval.start
            let bitisTarihi = monthInterval.end
            
            // YENİ: Tüm ay verisini bir kerede çek ve cache'le
            fetchMonthData(start: baslangicTarihi, end: bitisTarihi)
            isDataStale = false
            lastFetchDate = currentDate
            
            // Cache'den ilgili tür verisini al
            self.filtrelenmisIslemler = cachedMonthData[secilenTur] ?? []
            self.hesaplamalariGuncelle()

        } catch {
            Logger.log("Dashboard veri çekme hatası: \(error.localizedDescription)", log: Logger.data, type: .error)
            self.filtrelenmisIslemler = []
            self.hesaplamalariGuncelle()
        }
    }
    
    // YENİ: Ay verisini türlere göre cache'le
    private func fetchMonthData(start: Date, end: Date) {
        do {
            let descriptor = FetchDescriptor<Islem>(
                predicate: #Predicate { islem in
                    islem.tarih >= start && islem.tarih < end
                },
                sortBy: [SortDescriptor(\.tarih, order: .reverse)]
            )
            
            let allTransactions = try modelContext.fetch(descriptor)
            
            // Türlere göre grupla ve cache'le
            cachedMonthData[.gelir] = allTransactions.filter { $0.tur == .gelir }
            cachedMonthData[.gider] = allTransactions.filter { $0.tur == .gider }
            
        } catch {
            Logger.log("Ay verisi cache'leme hatası: \(error)", log: Logger.data, type: .error)
        }
    }
    
    // YENİ: Optimize edilmiş hesaplama
    private func hesaplamalariGuncelle() {
        // Performans: Array yerine reduce kullan
        toplamTutar = filtrelenmisIslemler.reduce(0) { $0 + $1.tutar }
        
        // Kategori detaylarını sadece bir kez hesapla
        var tempKategoriDetaylari: [String: (renk: Color, ikon: String, key: String?)] = [:]
        var kategoriTutarlari: [String: Double] = [:]
        
        for islem in filtrelenmisIslemler {
            guard let kategori = islem.kategori else { continue }
            
            let kategoriAdi = kategori.isim
            
            // Kategori detaylarını sadece ilk karşılaşmada ekle
            if tempKategoriDetaylari[kategoriAdi] == nil {
                tempKategoriDetaylari[kategoriAdi] = (kategori.renk, kategori.ikonAdi, kategori.localizationKey)
            }
            
            // Tutarları topla
            kategoriTutarlari[kategoriAdi, default: 0] += islem.tutar
        }
        
        self.kategoriDetaylari = tempKategoriDetaylari.mapValues { ($0.renk, $0.ikon) }
        
        // Chart verisi oluştur
        var chartData: [KategoriHarcamasi] = []
        var digerTutar: Double = 0.0
        
        // En yüksek 4 kategoriyi al
        let sortedCategories = kategoriTutarlari.sorted { $0.value > $1.value }
        
        for (index, (kategoriAdi, tutar)) in sortedCategories.enumerated() {
            if kategoriAdi == "Diğer" {
                digerTutar += tutar
                continue
            }
            
            if index < 4 {
                let detay = tempKategoriDetaylari[kategoriAdi]
                chartData.append(KategoriHarcamasi(
                    kategori: kategoriAdi,
                    tutar: tutar,
                    renk: detay?.renk ?? .gray,
                    localizationKey: detay?.key
                ))
            } else {
                digerTutar += tutar
            }
        }
        
        if digerTutar > 0 {
            chartData.append(KategoriHarcamasi(
                kategori: "Diğer",
                tutar: digerTutar,
                renk: .gray,
                localizationKey: "category.other"
            ))
        }
        
        self.pieChartVerisi = chartData
    }
    
    // GÜNCELLENMİŞ FONKSİYON
    func deleteIslem(_ islem: Islem) {
        TransactionService.shared.deleteTransaction(islem, in: modelContext)
        
        // Cache'i invalidate et
        invalidateCache()
        
        fetchData()
    }
    
    // GÜNCELLENMİŞ FONKSİYON
    func deleteSeri(for islem: Islem) {
        Task {
            isDeleting = true
            await TransactionService.shared.deleteSeriesInBackground(tekrarID: islem.tekrarID, from: modelContainer)
            
            // Cache'i invalidate et çünkü birden fazla işlem silinmiş olabilir
            invalidateCache()
            fetchData()
            
            isDeleting = false
        }
    }
}
