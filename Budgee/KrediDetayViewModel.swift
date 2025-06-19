// Dosya Adı: KrediDetayViewModel.swift

import SwiftUI
import SwiftData

@MainActor
@Observable
class KrediDetayViewModel {
    var modelContext: ModelContext
    var hesap: Hesap
    
    var giderEkleUyarisiGoster = false
    var islemOlusturulacakTaksit: KrediTaksitDetayi?
    
    init(modelContext: ModelContext, hesap: Hesap) {
        self.modelContext = modelContext
        self.hesap = hesap
    }
    
    func taksidiOde(taksit: KrediTaksitDetayi) {
        self.islemOlusturulacakTaksit = taksit
        self.giderEkleUyarisiGoster = true
    }
    
    func taksidiOnaylaVeGiderEkle(onayla: Bool) {
        guard let taksit = islemOlusturulacakTaksit else { return }
        
        guard case .kredi(let cekilenTutar, let faizTipi, let faizOrani, let taksitSayisi, let ilkTaksitTarihi, var taksitler) = hesap.detay else { return }
        guard let index = taksitler.firstIndex(where: { $0.id == taksit.id }) else { return }
        
        taksitler[index].odendiMi = true
        hesap.detay = .kredi(cekilenTutar: cekilenTutar, faizTipi: faizTipi, faizOrani: faizOrani, taksitSayisi: taksitSayisi, ilkTaksitTarihi: ilkTaksitTarihi, taksitler: taksitler)

        if onayla {
            guard let kategori = krediKategorisiniGetir() else {
                fatalError("'Kredi Ödemesi' kategorisi bulunamadı.")
            }
            
            // --- DEĞİŞİKLİK BURADA ---
            // Lokalize edilebilir formatı alıyoruz
            let formatString = NSLocalizedString("transaction.loan_payment_name_format", comment: "")
            // Kredinin adını formatın içine yerleştiriyoruz
            let islemAdi = String(format: formatString, hesap.isim)

            let yeniIslem = Islem(
                isim: islemAdi, // Lokalize edilmiş adı kullanıyoruz
                tutar: taksit.taksitTutari,
                tarih: Date(),
                tur: .gider,
                kategori: kategori,
                hesap: nil
            )
            modelContext.insert(yeniIslem)
        }
        
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .transactionsDidChange, object: nil)
        }
        islemOlusturulacakTaksit = nil
    }
    
    // Fonksiyon artık sadece kategoriyi bulup getiriyor, oluşturma mantığı kaldırıldı.
    private func krediKategorisiniGetir() -> Kategori? {
        let kategoriAdi = "Kredi Ödemesi"
        let predicate = #Predicate<Kategori> { $0.isim == kategoriAdi }
        let descriptor = FetchDescriptor(predicate: predicate)
        return try? modelContext.fetch(descriptor).first
    }
}
