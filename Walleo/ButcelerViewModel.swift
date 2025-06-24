import SwiftUI
import SwiftData

@MainActor
@Observable
class ButcelerViewModel {
    var modelContext: ModelContext
    var gosterilecekButceler: [GosterilecekButce] = []
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(hesaplamalariTetikle),
            name: .transactionsDidChange,
            object: nil
        )
    }
    
    @objc func hesaplamalariTetikle(notification: Notification) {
        guard let payload = notification.userInfo?["payload"] as? TransactionChangePayload else {
            Task { await butceDurumlariniHesapla() }
            return
        }
        
        // Bütçeler sadece giderlerden etkilenir
        let secilenKategori = payload.affectedCategoryIDs.first
        
        // Bütçelerimin içerdiği tüm kategori ID'lerini al
        let budgetCategoryIDs = Set(gosterilecekButceler.flatMap { $0.butce.kategoriler?.map { $0.id } ?? [] })
        
        // Eğer etkilenen kategori, benim bütçelerimden herhangi birinde varsa güncelleme yap
        if let kategoriID = secilenKategori, budgetCategoryIDs.contains(kategoriID) {
            Task { await butceDurumlariniHesapla() }
        } else {
            print("ButcelerViewModel: Değişiklik fark edildi ancak ilgili kategori bulunmadığı için güncelleme yapılmadı.")
        }
    }

    func deleteButce(_ butce: Butce) {
        // Önce modeli veritabanından sil.
        modelContext.delete(butce)
        
        // Şimdi, bu silme işleminin ekrana yansıması için
        // listeyi yeniden hesaplama fonksiyonunu tetikle.
        Task {
            await butceDurumlariniHesapla()
        }
    }
    func butceDurumlariniHesapla() async {
        let calendar = Calendar.current
        guard let monthInterval = calendar.dateInterval(of: .month, for: Date()) else { return }

        do {
            let butceDescriptor = FetchDescriptor<Butce>(sortBy: [SortDescriptor(\.olusturmaTarihi)])
            let tumButceler = try modelContext.fetch(butceDescriptor)
            
            // --- DÜZELTME BAŞLANGICI ---
            // 1. ADIM: Bu aydaki TÜM gider işlemlerini tek bir sorguyla çek.
            let giderTuruRawValue = IslemTuru.gider.rawValue
            let genelIslemPredicate = #Predicate<Islem> { islem in
                islem.tarih >= monthInterval.start &&
                islem.tarih < monthInterval.end &&
                islem.turRawValue == giderTuruRawValue
            }
            let tumAylikGiderler = try modelContext.fetch(FetchDescriptor<Islem>(predicate: genelIslemPredicate))
            
            // Verimlilik için işlemleri kategorilerine göre grupla.
            let kategoriyeGoreIslemler = Dictionary(grouping: tumAylikGiderler) { $0.kategori?.id }
            // --- DÜZELTME SONU ---
            
            var yeniGosterilecekler: [GosterilecekButce] = []
            
            for butce in tumButceler {
                var harcananTutar: Double = 0
                let butceninKategoriIDleri = Set(butce.kategoriler?.map { $0.id } ?? [])
                
                if !butceninKategoriIDleri.isEmpty {
                    // --- DÜZELTME BAŞLANGICI ---
                    // 2. ADIM: Veritabanına tekrar gitmek yerine, hafızadaki veriyi filtrele.
                    let ilgiliIslemler = butceninKategoriIDleri.flatMap { kategoriID in
                        kategoriyeGoreIslemler[kategoriID] ?? []
                    }
                    harcananTutar = ilgiliIslemler.reduce(0) { $0 + $1.tutar }
                    // --- DÜZELTME SONU ---
                }
                
                yeniGosterilecekler.append(GosterilecekButce(butce: butce, harcananTutar: harcananTutar))
            }
            
            self.gosterilecekButceler = yeniGosterilecekler
            
        } catch {
            Logger.log("Bütçe durumları hesaplanırken hata oluştu: \(error.localizedDescription)", log: Logger.data, type: .error)
        }
    }
}
