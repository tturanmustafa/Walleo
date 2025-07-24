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
    
    // YENİ: Premium kontrolü için
    var premiumLimitUyarisiGoster = false
    var limitAsilanHesapTuru: HesapTuru?
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        
        // Mevcut bildirim dinleyiciniz
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(hesaplamalariTetikle),
            name: .transactionsDidChange,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(hesaplamalariTetikle),
            name: .accountDetailsDidChange,
            object: nil
        )
    }
    
    // YENİ: Hesap limiti kontrolü
    func canCreateAccountType(_ type: HesapTuru, isPremium: Bool) -> Bool {
        // Premium kullanıcılar sınırsız hesap oluşturabilir
        if isPremium {
            return true
        }
        
        // Premium olmayan kullanıcılar için kontrol
        switch type {
        case .cuzdan:
            return cuzdanHesaplari.count < 1
        case .krediKarti:
            return krediKartiHesaplari.count < 1
        case .kredi:
            return krediHesaplari.count < 1
        }
    }
    
    // YENİ: Limit aşımı kontrolü
    func checkAndShowLimitWarning(for type: HesapTuru, isPremium: Bool) -> Bool {
        if !canCreateAccountType(type, isPremium: isPremium) {
            limitAsilanHesapTuru = type
            premiumLimitUyarisiGoster = true
            return true // Limit aşıldı
        }
        return false // Limit aşılmadı
    }
    
    // Mevcut fonksiyonlar aynı kalacak...
    @objc func hesaplamalariTetikle() {
        Task { await hesaplamalariYap() }
    }
    
    // hesaplamalariYap() ve diğer fonksiyonlar aynı kalacak...
    func hesaplamalariYap() async {
        // Mevcut kod aynı kalacak
        do {
            let hesaplar = try modelContext.fetch(FetchDescriptor<Hesap>(sortBy: [SortDescriptor(\.olusturmaTarihi)]))
            let islemler = try modelContext.fetch(FetchDescriptor<Islem>())
            let transferler = try modelContext.fetch(FetchDescriptor<Transfer>())
            
            // İşlem bazlı değişimler
            var netDegisimler: [UUID: Double] = [:]
            for islem in islemler {
                guard let hesapID = islem.hesap?.id else { continue }
                let tutarDegisimi = islem.tur == .gelir ? islem.tutar : -islem.tutar
                netDegisimler[hesapID, default: 0] += tutarDegisimi
            }
            
            // Transfer bazlı değişimler
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
                let transferDegisimi = transferDegisimleri[hesap.id] ?? 0
                let toplamDegisim = islemDegisimi + transferDegisimi
                let guncelBakiye = hesap.baslangicBakiyesi + toplamDegisim
                
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
    
    // Diğer mevcut fonksiyonlar aynı kalacak...
    func silmeIsleminiBaslat(hesap: Hesap) {
        // Mevcut kod aynı kalacak
        guard let islemler = hesap.islemler, !islemler.isEmpty else {
            self.silinecekHesap = hesap
            return
        }
        
        let gelirIceriyorMu = islemler.contains { $0.tur == .gelir }
        let digerHesaplar = (try? modelContext.fetch(FetchDescriptor<Hesap>()))?.filter { $0.id != hesap.id } ?? []
        
        var uygunHesaplar: [Hesap] = []
        
        if gelirIceriyorMu {
            uygunHesaplar = digerHesaplar.filter {
                if case .cuzdan = $0.detay { return true }
                return false
            }
            
            if uygunHesaplar.isEmpty {
                self.sadeceCuzdanGerekliUyarisiGoster = true
                return
            }
            
        } else {
            uygunHesaplar = digerHesaplar.filter {
                if case .kredi = $0.detay { return false }
                return true
            }
        }
        
        if uygunHesaplar.isEmpty {
            self.uygunHesapYokUyarisiGoster = true
        } else {
            self.uygunAktarimHesaplari = uygunHesaplar
            self.aktarilacakHesap = hesap
        }
    }
    
    func hesabiSilVeIslemleriAktar(hedefHesap: Hesap) {
        // Mevcut kod aynı kalacak
        guard let kaynakHesap = aktarilacakHesap,
              let kaynakIslemler = kaynakHesap.islemler else {
            return
        }
        
        Logger.log("İşlem aktarımı başladı: \(kaynakIslemler.count) adet işlem \(kaynakHesap.isim) -> \(hedefHesap.isim) hesabına aktarılacak.", log: Logger.service)
        
        for islem in kaynakIslemler {
            islem.hesap = hedefHesap
        }
        
        modelContext.delete(kaynakHesap)
        
        do {
            try modelContext.save()
            Logger.log("İşlem aktarımı ve hesap silme başarılı.", log: Logger.service)
            NotificationCenter.default.post(name: .transactionsDidChange, object: nil)
            Task { await hesaplamalariYap() }
        } catch {
            Logger.log("Hesap silme ve işlem aktarma sırasında hata: \(error.localizedDescription)", log: Logger.data, type: .error)
        }
        
        self.aktarilacakHesap = nil
        self.uygunAktarimHesaplari = []
    }

    func basitHesabiSil() {
        // Mevcut kod aynı kalacak
        guard let hesap = silinecekHesap else { return }
        
        if let iliskiliIslemler = hesap.islemler {
            for islem in iliskiliIslemler {
                islem.hesap = nil
            }
        }
        
        modelContext.delete(hesap)
        
        do {
            try modelContext.save()
            Task { await hesaplamalariYap() }
            NotificationCenter.default.post(name: .transactionsDidChange, object: nil)
        } catch {
            Logger.log("Basit hesap silme hatası: \(error)", log: Logger.service, type: .error)
        }
        
        self.silinecekHesap = nil
    }
}
