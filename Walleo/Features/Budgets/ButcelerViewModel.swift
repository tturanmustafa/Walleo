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
        
        let secilenKategori = payload.affectedCategoryIDs.first
        let budgetCategoryIDs = Set(gosterilecekButceler.flatMap { $0.butce.kategoriler?.map { $0.id } ?? [] })
        
        if let kategoriID = secilenKategori, budgetCategoryIDs.contains(kategoriID) {
            Task { await butceDurumlariniHesapla() }
        }
    }

    func deleteButce(_ butce: Butce) {
        modelContext.delete(butce)
        Task {
            await butceDurumlariniHesapla()
        }
    }
    
    // YENİDEN YAZILAN, DERLEYİCİ DOSTU FONKSİYON
    func butceDurumlariniHesapla() async {
        let calendar = Calendar.current
        guard let monthInterval = calendar.dateInterval(of: .month, for: Date()) else { return }

        do {
            let butceDescriptor = FetchDescriptor<Butce>(sortBy: [SortDescriptor(\.olusturmaTarihi)])
            let tumButceler = try modelContext.fetch(butceDescriptor)
            
            let giderTuruRawValue = IslemTuru.gider.rawValue
            let genelIslemPredicate = #Predicate<Islem> { islem in
                islem.tarih >= monthInterval.start &&
                islem.tarih < monthInterval.end &&
                islem.turRawValue == giderTuruRawValue
            }
            let tumAylikGiderler = try modelContext.fetch(FetchDescriptor<Islem>(predicate: genelIslemPredicate))
            
            // Verimlilik için işlemleri kategorilerine göre grupla. Bu kısım doğru ve hızlı.
            let kategoriyeGoreIslemler = Dictionary(grouping: tumAylikGiderler) { $0.kategori?.id }
            
            var yeniGosterilecekler: [GosterilecekButce] = []
            
            for butce in tumButceler {
                var harcananTutar: Double = 0.0
                
                // --- DÜZELTİLEN BÖLÜM BAŞLANGICI ---
                // Karmaşık flatMap/reduce yerine basit bir for döngüsü kullanıyoruz.
                // Bu, derleyicinin işini çok kolaylaştırır.
                if let butceninKategorileri = butce.kategoriler {
                    for kategori in butceninKategorileri {
                        if let islemler = kategoriyeGoreIslemler[kategori.id] {
                            // Her kategorinin işlemlerini topla
                            let buKategorininToplami = islemler.reduce(0) { $0 + $1.tutar }
                            harcananTutar += buKategorininToplami
                        }
                    }
                }
                // --- DÜZELTİLEN BÖLÜM SONU ---
                
                yeniGosterilecekler.append(GosterilecekButce(butce: butce, harcananTutar: harcananTutar))
            }
            
            self.gosterilecekButceler = yeniGosterilecekler
            
        } catch {
            Logger.log("Bütçe durumları hesaplanırken hata oluştu: \(error.localizedDescription)", log: Logger.data, type: .error)
        }
    }
}
