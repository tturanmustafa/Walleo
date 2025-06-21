// Dosya Adı: KrediDetayViewModel.swift (NİHAİ - TÜM DEĞİŞİKLİKLER UYGULANMIŞ)

import SwiftUI
import SwiftData

// GÜNCELLEME: Sınıf, çökme riskini ortadan kaldırmak için @MainActor olarak işaretlendi.
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
                // Bu kategori varsayılan olarak eklendiği için normalde bulunması gerekir.
                // Eğer bulunamazsa bir hata oluşmuş demektir.
                print("KRİTİK HATA: 'Kredi Ödemesi' kategorisi veritabanında bulunamadı.")
                return
            }
            
            let yeniIslem = Islem(
                // --- GÜNCELLEME: İsteğiniz doğrultusunda isimlendirme mantığı değiştirildi ---
                // Artık "Deneme Taksit Ödemesi" yerine doğrudan kredinin adı "Deneme" olarak atanıyor.
                isim: hesap.isim,
                tutar: taksit.taksitTutari,
                tarih: Date(), // Ödemenin yapıldığı anki tarih
                tur: .gider,
                kategori: kategori,
                hesap: nil // Kredi ödemeleri genellikle bir cüzdan/banka hesabından yapılır,
                           // bu yüzden bu işlem başka bir hesaba bağlanmamalı.
                           // Kullanıcı isterse bunu işlem detayından düzenleyebilir.
            )
            modelContext.insert(yeniIslem)
        }
        
        // Değişiklikleri tüm uygulamaya bildirelim.
        NotificationCenter.default.post(name: .transactionsDidChange, object: nil)
        
        // Uyarıyı kapatmak için state'i sıfırla
        islemOlusturulacakTaksit = nil
    }
    
    private func krediKategorisiniGetir() -> Kategori? {
        let kategoriAdi = "Kredi Ödemesi"
        let predicate = #Predicate<Kategori> { $0.isim == kategoriAdi }
        let descriptor = FetchDescriptor(predicate: predicate)
        
        // fetch işlemi potansiyel olarak hata fırlatabilir, güvenli hale getirelim.
        do {
            return try modelContext.fetch(descriptor).first
        } catch {
            print("Kredi kategorisi çekilirken hata oluştu: \(error)")
            return nil
        }
    }
}
