import SwiftUI
import SwiftData

@MainActor
@Observable
class ButcelerViewModel {
    var modelContext: ModelContext
    
    var gruplanmisButceler: [Date: [GosterilecekButce]] = [:]
    var siraliAylar: [Date] = []
    var gosterilecekButceler: [GosterilecekButce] = []
    
    // Performans için cache
    private var lastFetchDate: Date?
    private let cacheDuration: TimeInterval = 3.0
    private var isUpdating = false
    
    // MARK: - Init & Notification
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDataChange),
            name: .transactionsDidChange,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    /// Gelen bildirimin içeriğini kontrol eder ve duruma göre hedefli veya genel güncelleme yapar.
    @objc private func handleDataChange(notification: Notification) {
        // Güncelleme zaten devam ediyorsa yeni güncelleme başlatma
        guard !isUpdating else { return }
        
        if let payload = notification.userInfo?["payload"] as? TransactionChangePayload,
           let categoryID = payload.affectedCategoryIDs.first {
            Logger.log("Hedefli bütçe güncellemesi tetiklendi. Kategori ID: \(categoryID)", log: Logger.service)
            Task {
                await updateTargetedBudgets(for: categoryID)
            }
        } else {
            Logger.log("Genel bütçe güncellemesi tetiklendi.", log: Logger.service)
            Task {
                await updateAllBudgets()
            }
        }
    }
    
    // MARK: - Ana Fonksiyonlar
    
    func hesaplamalariTetikle() {
        // Cache kontrolü
        if let lastFetch = lastFetchDate,
           Date().timeIntervalSince(lastFetch) < cacheDuration {
            Logger.log("Cache hala geçerli, yeniden yükleme atlandı", log: Logger.service)
            return
        }
        
        Task {
            await updateAllBudgets()
        }
    }

    func deleteButce(_ butce: Butce) {
        modelContext.delete(butce)
        try? modelContext.save()
        
        // Silme sonrası cache'i invalidate et
        lastFetchDate = nil
        hesaplamalariTetikle()
    }
    
    // MARK: - Güncelleme Stratejileri
    
    /// "Hızlı Yol": Sadece belirli bir kategoriyi içeren bütçelerin harcamalarını yeniden hesaplar.
    private func updateTargetedBudgets(for categoryID: UUID) async {
        await MainActor.run {
            // 1. Sadece etkilenen bütçeleri mevcut listemizden bul.
            let etkilenenButceIDleri = gosterilecekButceler
                .filter { $0.butce.kategoriler?.contains(where: { $0.id == categoryID }) ?? false }
                .map { $0.id }
            
            guard !etkilenenButceIDleri.isEmpty else { return }
            
            // 2. Verimlilik için o ayın tüm giderlerini sadece bir kez veritabanından çek.
            do {
                let butceAraligi = Calendar.current.dateInterval(of: .month, for: Date())!
                let giderTuruRawValue = IslemTuru.gider.rawValue
                let descriptor = FetchDescriptor<Islem>(predicate: #Predicate { $0.turRawValue == giderTuruRawValue && $0.tarih >= butceAraligi.start && $0.tarih < butceAraligi.end })
                let tumAylikGiderler = try modelContext.fetch(descriptor)
                
                // 3. Ana listedeki etkilenen bütçeleri bul ve harcamalarını güncelle.
                for i in 0..<gosterilecekButceler.count {
                    if etkilenenButceIDleri.contains(gosterilecekButceler[i].id) {
                        gosterilecekButceler[i].harcananTutar = calculateSpending(for: gosterilecekButceler[i].butce, using: tumAylikGiderler)
                    }
                }
                
                // 4. Listeyi yeniden grupla ve sırala (veritabanı okuması olmadan).
                regroupAndSort()
                
            } catch {
                 Logger.log("Hedefli bütçe güncellemesi sırasında hata: \(error.localizedDescription)", log: Logger.data, type: .error)
            }
        }
    }
    
    /// "Güvenli Yol": Tüm bütçelerin harcamalarını en baştan, veritabanından okuyarak hesaplar.
    private func updateAllBudgets() async {
        await MainActor.run {
            do {
                let butceDescriptor = FetchDescriptor<Butce>(sortBy: [SortDescriptor(\.periyot, order: .reverse)])
                let tumButceler = try modelContext.fetch(butceDescriptor)
                
                let giderTuruRawValue = IslemTuru.gider.rawValue
                let descriptor = FetchDescriptor<Islem>(predicate: #Predicate { $0.turRawValue == giderTuruRawValue })
                let tumGiderler = try modelContext.fetch(descriptor)
                
                var yeniGosterilecekler: [GosterilecekButce] = []
                for butce in tumButceler {
                    let butceAraligi = Calendar.current.dateInterval(of: .month, for: butce.periyot)!
                    let butceGiderleri = tumGiderler.filter { $0.tarih >= butceAraligi.start && $0.tarih < butceAraligi.end }
                    let harcanan = calculateSpending(for: butce, using: butceGiderleri)
                    yeniGosterilecekler.append(GosterilecekButce(butce: butce, harcananTutar: harcanan))
                }
                
                self.gosterilecekButceler = yeniGosterilecekler
                regroupAndSort()
                
            } catch {
                Logger.log("Genel bütçe güncellemesi sırasında hata: \(error.localizedDescription)", log: Logger.data, type: .error)
            }
        }
    }
    // MARK: - Yardımcı Fonksiyonlar
    
    /// Tek bir bütçenin harcamasını, önceden çekilmiş işlem listesini kullanarak hesaplar.
    private func calculateSpending(for budget: Butce, using transactions: [Islem]) -> Double {
        let kategoriIDleri = Set(budget.kategoriler?.map { $0.id } ?? [])
        guard !kategoriIDleri.isEmpty else { return 0.0 }
        
        let harcananTutar = transactions.filter { islem in
            guard let kategoriID = islem.kategori?.id else { return false }
            return kategoriIDleri.contains(kategoriID)
        }.reduce(0) { $0 + $1.tutar }
        
        return harcananTutar
    }
    
    /// Mevcut `gosterilecekButceler` listesini aylara göre gruplar ve sıralar.
    private func regroupAndSort() {
        self.gruplanmisButceler = Dictionary(grouping: gosterilecekButceler) {
            Calendar.current.startOfDay(for: $0.butce.periyot)
        }
        self.siraliAylar = self.gruplanmisButceler.keys.sorted(by: >)
    }
}
