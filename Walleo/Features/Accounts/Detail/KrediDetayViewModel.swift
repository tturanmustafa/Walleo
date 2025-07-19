// Dosya Adı: KrediDetayViewModel.swift

import SwiftUI
import SwiftData

@MainActor
@Observable
class KrediDetayViewModel {
    var modelContext: ModelContext
    var hesap: Hesap
    
    // --- YENİ STATE'LER ---
    var odemeHesaplari: [Hesap] = []
    var islemYapilacakTaksit: KrediTaksitDetayi?
    
    var giderEkleUyarisiGoster = false
    var uygunHesapYokUyarisiGoster = false
    var hesapSecimSayfasiniGoster = false
    
    init(modelContext: ModelContext, hesap: Hesap) {
        self.modelContext = modelContext
        self.hesap = hesap
    }
    
    // 1. Adım: Kullanıcı bir taksidi ödemek istediğinde bu fonksiyon tetiklenir.
    func taksidiOdemeyiBaslat(taksit: KrediTaksitDetayi) {
        self.islemYapilacakTaksit = taksit
        self.giderEkleUyarisiGoster = true
    }
    
    // 2. Adım: Kullanıcı "Gider Olarak Ekle" uyarısında "Evet" derse bu fonksiyon çalışır.
    func giderOlarakEklemeyiOnayla() {
        fetchOdemeHesaplari()
        
        if odemeHesaplari.isEmpty {
            // Eğer uygun hesap yoksa, View'a uyarı göstermesi için sinyal gönder.
            uygunHesapYokUyarisiGoster = true
        } else {
            // Eğer uygun hesap varsa, View'a seçim ekranını göstermesi için sinyal gönder.
            hesapSecimSayfasiniGoster = true
        }
    }

    // 3. Adım: Kullanıcı seçim ekranından bir hesap seçtiğinde bu fonksiyon çalışır.
    func giderIsleminiOlustur(hesap: Hesap) {
        guard let taksit = islemYapilacakTaksit else { return }
        
        taksidiOnayla(taksit: taksit, islemOlusturulsun: true, secilenHesap: hesap)
    }
    
    // 4. Adım: Kullanıcı "Gider Olarak Ekleme" derse bu fonksiyon çalışır.
    func sadeceOdenmisIsaretle() {
        guard let taksit = islemYapilacakTaksit else { return }
        
        taksidiOnayla(taksit: taksit, islemOlusturulsun: false, secilenHesap: nil)
    }
    
    // 5. Adım (Merkezi Mantık): Taksidi onaylayan ve isteğe bağlı olarak gider ekleyen ana fonksiyon.
    private func taksidiOnayla(taksit: KrediTaksitDetayi, islemOlusturulsun: Bool, secilenHesap: Hesap?) {
        do {
            guard case .kredi(let cekilenTutar, let faizTipi, let faizOrani, let taksitSayisi, let ilkTaksitTarihi, var taksitler) = hesap.detay else {
                Logger.log("Kredi detayı alınamadı", log: Logger.service, type: .error)
                return
            }
            
            guard let index = taksitler.firstIndex(where: { $0.id == taksit.id }) else {
                Logger.log("Taksit bulunamadı", log: Logger.service, type: .error)
                return
            }
            
            // Taksit durumunu güncelle
            taksitler[index].odendiMi = true
            hesap.detay = .kredi(
                cekilenTutar: cekilenTutar,
                faizTipi: faizTipi,
                faizOrani: faizOrani,
                taksitSayisi: taksitSayisi,
                ilkTaksitTarihi: ilkTaksitTarihi,
                taksitler: taksitler
            )
            
            var affectedAccountIDs: Set<UUID> = [hesap.id]
            
            // Gider olarak ekle
            if islemOlusturulsun, let odemeHesabi = secilenHesap {
                guard let kategori = krediKategorisiniGetir() else {
                    Logger.log("Kredi kategorisi bulunamadı", log: Logger.data, type: .error)
                    return
                }
                
                // --- DÜZELTME BURADA ---
                // İşlem adını sadece kredinin kendi adı olarak ayarlıyoruz.
                let yeniIslem = Islem(
                    isim: hesap.isim,
                    tutar: taksit.taksitTutari,
                    tarih: Date(),
                    tur: .gider,
                    kategori: kategori,
                    hesap: odemeHesabi
                )
                
                modelContext.insert(yeniIslem)
                affectedAccountIDs.insert(odemeHesabi.id)
            }
            
            // Değişiklikleri kaydet
            try modelContext.save()
            
            // Bildirim gönder
            NotificationCenter.default.post(
                name: .transactionsDidChange,
                object: nil,
                userInfo: ["payload": TransactionChangePayload(
                    type: .update,
                    affectedAccountIDs: Array(affectedAccountIDs),
                    affectedCategoryIDs: []
                )]
            )
            
            islemYapilacakTaksit = nil
            
        } catch {
            Logger.log("Taksit ödeme hatası: \(error)", log: Logger.service, type: .error)
        }
    }
    // 6. Adım (Yardımcı Fonksiyonlar)
    private func fetchOdemeHesaplari() {
        let descriptor = FetchDescriptor<Hesap>()
        let tumHesaplar = try? modelContext.fetch(descriptor)
        
        self.odemeHesaplari = tumHesaplar?.filter { hesap in
            if case .kredi = hesap.detay {
                return false // Kredi hesabıyla ödeme yapılamaz
            }
            return true
        } ?? []
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
