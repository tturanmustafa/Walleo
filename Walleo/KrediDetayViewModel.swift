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
                print("KRİTİK HATA: 'Kredi Ödemesi' kategorisi veritabanında bulunamadı.")
                return
            }
            
            let yeniIslem = Islem(
                isim: hesap.isim,
                tutar: taksit.taksitTutari,
                tarih: Date(),
                tur: .gider,
                kategori: kategori,
                hesap: nil
            )
            modelContext.insert(yeniIslem)
        }
        
        // --- GÜNCELLEME: Akıllı Bildirim Gönderimi ---
        // Taksit ödemesi kredi hesabının kendisini etkiler.
        let userInfo: [String: Any] = ["affectedAccountIDs": [hesap.id]]
        NotificationCenter.default.post(name: .transactionsDidChange, object: nil, userInfo: userInfo)
        
        islemOlusturulacakTaksit = nil
    }
    
    private func krediKategorisiniGetir() -> Kategori? {
        let kategoriAdi = "Kredi Ödemesi"
        let predicate = #Predicate<Kategori> { $0.isim == kategoriAdi }
        let descriptor = FetchDescriptor(predicate: predicate)
        do {
            return try modelContext.fetch(descriptor).first
        } catch {
            Logger.log("Kredi kategorisi çekilirken hata oluştu: \(error.localizedDescription)", log: Logger.data, type: .error)
            return nil
        }
    }
}
