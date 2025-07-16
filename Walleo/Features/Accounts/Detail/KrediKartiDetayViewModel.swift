// Dosya: Walleo/Features/Accounts/Detail/KrediKartiDetayViewModel.swift

import SwiftUI
import SwiftData

@MainActor
@Observable
class KrediKartiDetayViewModel {
    var modelContext: ModelContext
    var kartHesabi: Hesap
    
    var donemBaslangicTarihi: Date
    var donemBitisTarihi: Date
    var donemIslemleri: [Islem] = []
    
    var toplamHarcama: Double {
        donemIslemleri.reduce(0) { $0 + $1.tutar }
    }
    
    init(modelContext: ModelContext, kartHesabi: Hesap) {
        self.modelContext = modelContext
        self.kartHesabi = kartHesabi
        
        self.donemBaslangicTarihi = Date()
        self.donemBitisTarihi = Date()
        
        self.guncelDonemiHesapla(referansTarih: Date())
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(yenile),
            name: .transactionsDidChange,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(yenile),
            name: .accountDetailsDidChange,
            object: nil
        )
    }
    
    @objc func yenile() {
        // DÜZELTME: Veri değiştiğinde direkt olarak işlemleri getir.
        self.islemleriGetir()
    }

    // DÜZELTME: 'private' kaldırıldı, artık View tarafından erişilebilir.
    func islemleriGetir() {
        let takvim = Calendar.current
        let sorguBitisTarihi = takvim.date(byAdding: .day, value: 1, to: self.donemBitisTarihi)!
        
        let kartID = kartHesabi.id
        let giderTuruRawValue = IslemTuru.gider.rawValue
        
        // --- DERLEYİCİ HATASI İÇİN KESİN ÇÖZÜM ---
        let baslangic = self.donemBaslangicTarihi
        let bitis = sorguBitisTarihi
        
        // 1. ADIM: Sadece tarih ve türe göre basit bir sorgu oluştur.
        let basitPredicate = #Predicate<Islem> { islem in
            islem.tarih >= baslangic &&
            islem.tarih < bitis &&
            islem.turRawValue == giderTuruRawValue
        }
        
        let descriptor = FetchDescriptor<Islem>(predicate: basitPredicate, sortBy: [SortDescriptor(\.tarih, order: .reverse)])
        
        do {
            // 2. ADIM: Veritabanından ön-filtreli listeyi çek.
            let donemGiderleri = try modelContext.fetch(descriptor)
            
            // 3. ADIM: Nihai filtrelemeyi (hesap ID'sine göre) hafızada yap.
            self.donemIslemleri = donemGiderleri.filter { $0.hesap?.id == kartID }
            
        } catch {
            Logger.log("Kredi kartı detay işlemleri çekilirken hata: \(error.localizedDescription)", log: Logger.data, type: .error)
            self.donemIslemleri = []
        }
    }
    
    func sonrakiDonem() {
        // Mevcut dönemin bitiş tarihinden BİR GÜN SONRASINI referans al.
        guard let yeniReferansTarih = Calendar.current.date(byAdding: .day, value: 1, to: self.donemBitisTarihi) else { return }
        guncelDonemiHesapla(referansTarih: yeniReferansTarih)
    }

    /// Bir önceki ekstre dönemini yükler.
    func oncekiDonem() {
        // Mevcut dönemin başlangıç tarihinden BİR GÜN ÖNCESİNİ referans al.
        guard let yeniReferansTarih = Calendar.current.date(byAdding: .day, value: -1, to: self.donemBaslangicTarihi) else { return }
        guncelDonemiHesapla(referansTarih: yeniReferansTarih)
    }
    
    private func guncelDonemiHesapla(referansTarih: Date) {
        // --- BU SATIRDAKİ HATANIN ÇÖZÜMÜ ---
        // 1. Karşılaştırılacak ID'yi önce bir değişkene atıyoruz.
        let idToFetch = self.kartHesabi.id
        
        // 2. Predicate içinde `self` yerine bu yeni değişkeni kullanıyoruz.
        let hesapPredicate = #Predicate<Hesap> { $0.id == idToFetch }
        
        // Veritabanından en güncel hesap bilgisini çekiyoruz.
        guard let guncelHesap = try? modelContext.fetch(FetchDescriptor(predicate: hesapPredicate)).first else {
            return
        }
        self.kartHesabi = guncelHesap
        // --- ÇÖZÜM SONU ---
        
        guard case .krediKarti(_, let kesimTarihi, _) = kartHesabi.detay else { return }
        
        let takvim = Calendar.current
        let kesimGunu = takvim.component(.day, from: kesimTarihi)
        
        var referansBilesenleri = takvim.dateComponents([.year, .month], from: referansTarih)
        referansBilesenleri.day = kesimGunu
        
        guard let buAyinKesimTarihi = takvim.date(from: referansBilesenleri) else { return }
        
        if referansTarih < buAyinKesimTarihi {
            self.donemBitisTarihi = takvim.date(byAdding: .day, value: -1, to: buAyinKesimTarihi)!
            guard let gecenAyinKesimTarihi = takvim.date(byAdding: .month, value: -1, to: buAyinKesimTarihi) else { return }
            self.donemBaslangicTarihi = gecenAyinKesimTarihi
        } else {
            self.donemBaslangicTarihi = buAyinKesimTarihi
            guard let gelecekAyinKesimTarihi = takvim.date(byAdding: .month, value: 1, to: buAyinKesimTarihi) else { return }
            self.donemBitisTarihi = takvim.date(byAdding: .day, value: -1, to: gelecekAyinKesimTarihi)!
        }
        
        islemleriGetir()
    }
}
