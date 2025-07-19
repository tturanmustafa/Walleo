// Walleo/Features/Accounts/HesaplarViewModel.swift

import SwiftUI
import SwiftData

@MainActor
@Observable
class HesaplarViewModel {
    var modelContext: ModelContext
    
    // ViewModel artık doğrudan bu üç listeyi yönetiyor
    var cuzdanHesaplari: [GosterilecekHesap] = []
    var krediKartiHesaplari: [GosterilecekHesap] = []
    var krediHesaplari: [GosterilecekHesap] = []
    var silinecekHesap: Hesap? // Basit silme onayı için
    var aktarilacakHesap: Hesap? // İşlemleri aktarılacak hesap
    var uygunAktarimHesaplari: [Hesap] = [] // İşlemlerin aktarılabileceği hesap listesi
    var uygunHesapYokUyarisiGoster = false // Uyarı durumu
    var sadeceCuzdanGerekliUyarisiGoster = false
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        
        // Mevcut bildirim dinleyiciniz
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(hesaplamalariTetikle),
            name: .transactionsDidChange,
            object: nil
        )
        
        // --- 🔥 EKLENECEK KOD BURADA 🔥 ---
        // Hesap detayları değiştiğinde de listenin yenilenmesini sağlıyoruz.
        // Bu, yeni hesap eklendiğinde veya mevcut bir hesap düzenlendiğinde tetiklenir.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(hesaplamalariTetikle),
            name: .accountDetailsDidChange, // Doğru bildirimi dinliyoruz
            object: nil
        )
    }
    
    // Herhangi bir veri değişikliğinde bu fonksiyon tetiklenir.
    @objc func hesaplamalariTetikle() {
        Task { await hesaplamalariYap() }
    }
    
    // Bu ana fonksiyon, tüm hesapları ve bakiyeleri sıfırdan hesaplayıp doğru listelere atar.
    func hesaplamalariYap() async {
        do {
            let hesaplar = try modelContext.fetch(FetchDescriptor<Hesap>(sortBy: [SortDescriptor(\.olusturmaTarihi)]))
            let islemler = try modelContext.fetch(FetchDescriptor<Islem>())
            let transferler = try modelContext.fetch(FetchDescriptor<Transfer>()) // YENİ
            
            // İşlem bazlı değişimler
            var netDegisimler: [UUID: Double] = [:]
            for islem in islemler {
                guard let hesapID = islem.hesap?.id else { continue }
                let tutarDegisimi = islem.tur == .gelir ? islem.tutar : -islem.tutar
                netDegisimler[hesapID, default: 0] += tutarDegisimi
            }
            
            // Transfer bazlı değişimler - YENİ
            var transferDegisimleri: [UUID: Double] = [:]
            for transfer in transferler {
                if let kaynakID = transfer.kaynakHesap?.id {
                    transferDegisimleri[kaynakID, default: 0] -= transfer.tutar
                }
                if let hedefID = transfer.hedefHesap?.id {
                    transferDegisimleri[hedefID, default: 0] += transfer.tutar
                }
            }
            
            // Her seferinde listeleri temizle
            var yeniCuzdanlar: [GosterilecekHesap] = []
            var yeniKrediKartlari: [GosterilecekHesap] = []
            var yeniKrediler: [GosterilecekHesap] = []
            
            for hesap in hesaplar {
                let islemDegisimi = netDegisimler[hesap.id] ?? 0
                let transferDegisimi = transferDegisimleri[hesap.id] ?? 0 // YENİ
                let toplamDegisim = islemDegisimi + transferDegisimi // YENİ
                let guncelBakiye = hesap.baslangicBakiyesi + toplamDegisim // GÜNCELLENDİ
                
                var gosterilecekHesap = GosterilecekHesap(hesap: hesap, guncelBakiye: guncelBakiye)
                
                switch hesap.detay {
                case .cuzdan:
                    yeniCuzdanlar.append(gosterilecekHesap)
                    
                case .krediKarti(let limit, _, _):
                    // Kredi kartı için özel hesaplama
                    let initialBorc = abs(hesap.baslangicBakiyesi)
                    let harcamalar = islemler
                        .filter { $0.hesap?.id == hesap.id && $0.tur == .gider }
                        .reduce(0) { $0 + $1.tutar }
                    let odemeler = transferler
                        .filter { $0.hedefHesap?.id == hesap.id }
                        .reduce(0) { $0 + $1.tutar }
                    
                    let guncelBorc = initialBorc + harcamalar - odemeler
                    let kullanilabilirLimit = max(0, limit - guncelBorc)
                    
                    gosterilecekHesap.krediKartiDetay = .init(
                        guncelBorc: guncelBorc,
                        kullanilabilirLimit: kullanilabilirLimit
                    )
                    gosterilecekHesap.guncelBakiye = -guncelBorc
                    yeniKrediKartlari.append(gosterilecekHesap)
                    
                case .kredi(_, _, _, let taksitSayisi, _, let taksitler):
                    let odenenTaksitSayisi = taksitler.filter { $0.odendiMi }.count
                    gosterilecekHesap.krediDetay = .init(
                        kalanTaksitSayisi: taksitSayisi - odenenTaksitSayisi,
                        odenenTaksitSayisi: odenenTaksitSayisi
                    )
                    yeniKrediler.append(gosterilecekHesap)
                }
            }
            
            // Yeni listeleri ata
            self.cuzdanHesaplari = yeniCuzdanlar
            self.krediKartiHesaplari = yeniKrediKartlari
            self.krediHesaplari = yeniKrediler
            
        } catch {
            Logger.log("Hesap ViewModel genel hesaplama hatası: \(error.localizedDescription)", log: Logger.data, type: .error)
        }
    }
    
    // Silme fonksiyonu aynı kalabilir
    func silmeIsleminiBaslat(hesap: Hesap) {
        // 1. Silinecek hesabın işlemleri var mı?
        guard let islemler = hesap.islemler, !islemler.isEmpty else {
            // İşlemi yoksa, eski usul basit silme onayı göster.
            self.silinecekHesap = hesap
            return
        }
        
        // 2. İşlemlerin türünü analiz et: İçinde HİÇ gelir var mı?
        let gelirIceriyorMu = islemler.contains { $0.tur == .gelir }
        
        // 3. Aktarım için uygun diğer hesapları bul (silinecek olan hariç)
        let digerHesaplar = (try? modelContext.fetch(FetchDescriptor<Hesap>()))?.filter { $0.id != hesap.id } ?? []
        
        var uygunHesaplar: [Hesap] = []
        
        if gelirIceriyorMu {
            // EĞER GELİR İÇERİYORSA: Aktarım yapılacak hesaplar SADECE diğer cüzdanlar olabilir.
            uygunHesaplar = digerHesaplar.filter {
                if case .cuzdan = $0.detay { return true }
                return false
            }
            
            // Uygun cüzdan yoksa, özel bir uyarı göster.
            if uygunHesaplar.isEmpty {
                self.sadeceCuzdanGerekliUyarisiGoster = true
                return
            }
            
        } else {
            // EĞER SADECE GİDER VARSA: Aktarım yapılacak hesaplar cüzdanlar veya kredi kartları olabilir.
            uygunHesaplar = digerHesaplar.filter {
                if case .kredi = $0.detay { return false } // Kredi hesapları hariç
                return true
            }
        }
        
        // 4. Duruma göre yönlendir
        if uygunHesaplar.isEmpty {
            // Genel "uygun hesap yok" uyarısını göster. (Bu durum sadece gider varken ve başka hesap olmadığında tetiklenir)
            self.uygunHesapYokUyarisiGoster = true
        } else {
            // Aktarılacak uygun hesaplar varsa, aktarım ekranını tetikle.
            self.uygunAktarimHesaplari = uygunHesaplar
            self.aktarilacakHesap = hesap
        }
    }
    
    // --- YENİ FONKSİYON 2: ASIL SİLME VE AKTARMA İŞLEMİ ---
    /// Kullanıcı aktarım ekranında bir hedef hesap seçip onayladığında bu fonksiyon çalışır.
    func hesabiSilVeIslemleriAktar(hedefHesap: Hesap) {
        guard let kaynakHesap = aktarilacakHesap,
              let kaynakIslemler = kaynakHesap.islemler else {
            return
        }
        
        Logger.log("İşlem aktarımı başladı: \(kaynakIslemler.count) adet işlem \(kaynakHesap.isim) -> \(hedefHesap.isim) hesabına aktarılacak.", log: Logger.service)
        
        // 1. İşlemlerin hesap ilişkisini güncelle
        for islem in kaynakIslemler {
            islem.hesap = hedefHesap
        }
        
        // 2. Kaynak hesabı sil
        modelContext.delete(kaynakHesap)
        
        do {
            try modelContext.save()
            Logger.log("İşlem aktarımı ve hesap silme başarılı.", log: Logger.service)
            
            // 3. Değişiklikleri tüm uygulamaya bildir
            NotificationCenter.default.post(name: .transactionsDidChange, object: nil)
            
            // 4. Hesaplar listesini yenile
            Task { await hesaplamalariYap() }
            
        } catch {
            Logger.log("Hesap silme ve işlem aktarma sırasında hata: \(error.localizedDescription)", log: Logger.data, type: .error)
        }
        
        // State'leri temizle
        self.aktarilacakHesap = nil
        self.uygunAktarimHesaplari = []
    }

    // --- ESKİ `hesabiSil` FONKSİYONUNU GÜNCELLE ---
    /// Bu fonksiyon artık sadece işlemi olmayan hesapları veya kullanıcıdan onay alınmış basit silmeleri yapar.
    func basitHesabiSil() {
        guard let hesap = silinecekHesap else { return }
        
        // Hesaba bağlı işlemlerin ilişkisini kopar (bu senaryoda işlem olmamalı ama garanti olsun)
        if let iliskiliIslemler = hesap.islemler {
            for islem in iliskiliIslemler {
                islem.hesap = nil
            }
        }
        
        modelContext.delete(hesap)
        
        do {
            try modelContext.save()
            Task { await hesaplamalariYap() }
            // İşlem bağlantısı koptuğu için genel bir güncelleme bildirimi gönder
            NotificationCenter.default.post(name: .transactionsDidChange, object: nil)
        } catch {
            Logger.log("Basit hesap silme hatası: \(error)", log: Logger.service, type: .error)
        }
        
        self.silinecekHesap = nil
    }
}
