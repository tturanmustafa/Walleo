//
//  KrediRaporuViewModel.swift
//  Walleo
//
//  Created by Mustafa Turan on 14.07.2025.
//


// >> YENİ DOSYA: Features/Reports/KrediRaporuViewModel.swift

import SwiftUI
import SwiftData

@MainActor
@Observable
class KrediRaporuViewModel {
    private var modelContext: ModelContext
    var baslangicTarihi: Date
    var bitisTarihi: Date

    // Arayüzün kullanacağı, işlenmiş veriler
    var genelOzet = KrediGenelOzet()
    var krediDetayRaporlari: [KrediDetayRaporu] = []
    var isLoading = false
    
    // Gider olarak eklenmiş taksitleri ayrıca tutmak için
    var giderOlarakEklenenTaksitIDleri: Set<UUID> = []

    init(modelContext: ModelContext, baslangicTarihi: Date, bitisTarihi: Date) {
        self.modelContext = modelContext
        self.baslangicTarihi = baslangicTarihi
        self.bitisTarihi = bitisTarihi
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(triggerFetchData),
            name: .transactionsDidChange,
            object: nil
        )
    }

    @objc private func triggerFetchData() {
        Task { await fetchData() }
    }
    
    func fetchData() async {
        isLoading = true
        
        let sorguBitisTarihi = Calendar.current.date(byAdding: .day, value: 1, to: bitisTarihi) ?? bitisTarihi
        
        // 1. Tüm kredi hesaplarını çek
        let krediTuru = HesapTuru.kredi.rawValue
        let hesapPredicate = #Predicate<Hesap> { $0.hesapTuruRawValue == krediTuru }
        guard let krediHesaplari = try? modelContext.fetch(FetchDescriptor(predicate: hesapPredicate)) else {
            isLoading = false
            return
        }

        // 2. Tüm taksitleri ve ilgili işlemleri çek
        var tumDonemTaksitleri: [KrediTaksitDetayi] = []
        var tumRaporlar: [KrediDetayRaporu] = []
        
        for hesap in krediHesaplari {
            if case .kredi(_, _, _, _, _, let taksitler) = hesap.detay {
                let donemTaksitleri = taksitler.filter { $0.odemeTarihi >= baslangicTarihi && $0.odemeTarihi < sorguBitisTarihi }
                if !donemTaksitleri.isEmpty {
                    tumDonemTaksitleri.append(contentsOf: donemTaksitleri)
                    tumRaporlar.append(KrediDetayRaporu(id: hesap.id, hesap: hesap, donemdekiTaksitler: donemTaksitleri))
                }
            }
        }
        
        // 3. Gider olarak eklenen taksitleri bul
        await findAssociatedExpenseTransactions(for: tumDonemTaksitleri)

        // 4. Genel özeti hesapla
        var yeniGenelOzet = KrediGenelOzet()
        yeniGenelOzet.aktifKrediSayisi = tumRaporlar.count
        yeniGenelOzet.donemdekiToplamTaksitTutari = tumDonemTaksitleri.reduce(0) { $0 + $1.taksitTutari }
        let odenenTaksitler = tumDonemTaksitleri.filter { $0.odendiMi }
        yeniGenelOzet.odenenTaksitSayisi = odenenTaksitler.count
        yeniGenelOzet.odenenToplamTaksitTutari = odenenTaksitler.reduce(0) { $0 + $1.taksitTutari }
        yeniGenelOzet.odenmeyenTaksitSayisi = tumDonemTaksitleri.count - odenenTaksitler.count
        
        self.genelOzet = yeniGenelOzet
        self.krediDetayRaporlari = tumRaporlar.sorted(by: { $0.donemdekiTaksitTutari > $1.donemdekiTaksitTutari })
        
        isLoading = false
    }
    
    // Bir taksidin gider olarak eklenip eklenmediğini kontrol eden fonksiyon
    private func findAssociatedExpenseTransactions(for taksitler: [KrediTaksitDetayi]) async {
        let krediOdemeKategorisi = try? modelContext.fetch(FetchDescriptor<Kategori>(predicate: #Predicate { $0.isim == "Kredi Ödemesi" })).first
        guard let krediOdemeKategoriID = krediOdemeKategorisi?.id else { return }
        
        var bulunanIDler: Set<UUID> = []
        for taksit in taksitler where taksit.odendiMi {
            let tutar = taksit.taksitTutari
            let islemPredicate = #Predicate<Islem> { islem in
                islem.tutar == tutar && islem.kategori?.id == krediOdemeKategoriID
            }
            if let count = try? modelContext.fetchCount(FetchDescriptor(predicate: islemPredicate)), count > 0 {
                bulunanIDler.insert(taksit.id)
            }
        }
        self.giderOlarakEklenenTaksitIDleri = bulunanIDler
    }
}