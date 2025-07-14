import SwiftUI
import SwiftData

@MainActor
@Observable
class KrediRaporViewModel {
    var modelContext: ModelContext
    
    // Tarih aralığı
    var baslangicTarihi: Date
    var bitisTarihi: Date
    
    // Kredi verileri
    var krediler: [Hesap] = []
    var toplamKalanBorc: Double = 0
    var toplamOdenenTaksit: Double = 0
    var aktifKrediSayisi: Int = 0
    
    // Taksit detayları (her kredi için)
    struct KrediTaksitOzeti: Identifiable {
        let id = UUID()
        let krediAdi: String
        let krediID: UUID
        let toplamTaksitTutari: Double
        let odenenTaksitSayisi: Int
        let bekleyenTaksitSayisi: Int
        let giderOlarakIslenenTutar: Double
        let ilerlemeYuzdesi: Double
        let renk: Color
    }
    var krediTaksitOzetleri: [KrediTaksitOzeti] = []
    
    // Ödeme takvimi verileri
    struct OdemeTakvimGunu: Identifiable {
        let id = UUID()
        let tarih: Date
        let taksitler: [TaksitDetay]
        let toplamTutar: Double
        
        struct TaksitDetay {
            let krediAdi: String
            let tutar: Double
            let odendiMi: Bool
            let renk: Color
        }
    }
    var odemeTakvimiGunleri: [OdemeTakvimGunu] = []
    
    // Kredi karşılaştırma verileri (Radar chart için)
    struct KrediKarsilastirma: Identifiable {
        let id = UUID()
        let krediAdi: String
        let faizOrani: Double
        let kalanTaksitSayisi: Int
        let aylikYuk: Double // Aylık taksit tutarı
        let toplamKalanBorc: Double
        let renk: Color
    }
    var krediKarsilastirmalari: [KrediKarsilastirma] = []
    
    // Yükleme durumu
    var isLoading = false
    
    init(modelContext: ModelContext, baslangicTarihi: Date, bitisTarihi: Date) {
        self.modelContext = modelContext
        self.baslangicTarihi = baslangicTarihi
        self.bitisTarihi = bitisTarihi
    }
    
    func fetchData() async {
        isLoading = true
        defer { isLoading = false }
        
        // Tüm kredi hesaplarını çek
        await fetchKrediler()
        
        // Kredi taksit özetlerini hesapla
        await calculateKrediTaksitOzetleri()
        
        // Ödeme takvimini oluştur
        await generateOdemeTakvimi()
        
        // Kredi karşılaştırmalarını hazırla
        await prepareKrediKarsilastirmalari()
        
        // Genel metrikleri hesapla
        calculateGeneralMetrics()
    }
    
    private func fetchKrediler() async {
        do {
            let krediTuruRawValue = HesapTuru.kredi.rawValue
            let descriptor = FetchDescriptor<Hesap>(
                predicate: #Predicate { hesap in
                    hesap.hesapTuruRawValue == krediTuruRawValue
                }
            )
            krediler = try modelContext.fetch(descriptor)
        } catch {
            Logger.log("Krediler çekilirken hata: \(error)", log: Logger.data, type: .error)
        }
    }
    
    private func calculateKrediTaksitOzetleri() async {
        var ozetler: [KrediTaksitOzeti] = []
        
        for kredi in krediler {
            guard case .kredi(_, let faizTipi, _, let toplamTaksitSayisi, _, let taksitler) = kredi.detay else {
                continue
            }
            
            // Dönem içindeki taksitleri filtrele
            let donemTaksitleri = taksitler.filter { taksit in
                taksit.odemeTarihi >= baslangicTarihi && taksit.odemeTarihi <= bitisTarihi
            }
            
            let toplamTaksitTutari = donemTaksitleri.reduce(0) { $0 + $1.taksitTutari }
            let odenenTaksitSayisi = donemTaksitleri.filter { $0.odendiMi }.count
            let bekleyenTaksitSayisi = donemTaksitleri.filter { !$0.odendiMi }.count
            
            // Gider olarak işlenen tutarı hesapla (işlem kayıtlarından)
            let giderTutari = await calculateGiderTutari(for: kredi, in: donemTaksitleri)
            
            let tumOdenenTaksitSayisi = taksitler.filter { $0.odendiMi }.count
            let ilerlemeYuzdesi = Double(tumOdenenTaksitSayisi) / Double(toplamTaksitSayisi)
            
            let ozet = KrediTaksitOzeti(
                krediAdi: kredi.isim,
                krediID: kredi.id,
                toplamTaksitTutari: toplamTaksitTutari,
                odenenTaksitSayisi: odenenTaksitSayisi,
                bekleyenTaksitSayisi: bekleyenTaksitSayisi,
                giderOlarakIslenenTutar: giderTutari,
                ilerlemeYuzdesi: ilerlemeYuzdesi,
                renk: kredi.renk
            )
            
            ozetler.append(ozet)
        }
        
        self.krediTaksitOzetleri = ozetler
    }
    
    private func calculateGiderTutari(for kredi: Hesap, in taksitler: [KrediTaksitDetayi]) async -> Double {
        do {
            // Kredi ödemesi kategorisini bul
            let kategoriAdi = "Kredi Ödemesi"
            let kategoriPredicate = #Predicate<Kategori> { $0.isim == kategoriAdi }
            let kategoriDescriptor = FetchDescriptor(predicate: kategoriPredicate)
            
            guard let krediKategorisi = try modelContext.fetch(kategoriDescriptor).first else {
                return 0
            }
            
            // İşlemleri çek
            let giderTuruRawValue = IslemTuru.gider.rawValue
            let islemPredicate = #Predicate<Islem> { islem in
                islem.turRawValue == giderTuruRawValue &&
                islem.tarih >= baslangicTarihi &&
                islem.tarih <= bitisTarihi &&
                islem.kategori?.id == krediKategorisi.id &&
                islem.isim.contains(kredi.isim)
            }
            
            let islemDescriptor = FetchDescriptor(predicate: islemPredicate)
            let islemler = try modelContext.fetch(islemDescriptor)
            
            return islemler.reduce(0) { $0 + $1.tutar }
            
        } catch {
            Logger.log("Gider tutarı hesaplanırken hata: \(error)", log: Logger.data, type: .error)
            return 0
        }
    }
    
    private func generateOdemeTakvimi() async {
        var takvimGunleri: [Date: [OdemeTakvimGunu.TaksitDetay]] = [:]
        
        for kredi in krediler {
            guard case .kredi(_, _, _, _, _, let taksitler) = kredi.detay else {
                continue
            }
            
            // Dönem içindeki taksitleri al
            let donemTaksitleri = taksitler.filter { taksit in
                taksit.odemeTarihi >= baslangicTarihi && taksit.odemeTarihi <= bitisTarihi
            }
            
            for taksit in donemTaksitleri {
                let gun = Calendar.current.startOfDay(for: taksit.odemeTarihi)
                let detay = OdemeTakvimGunu.TaksitDetay(
                    krediAdi: kredi.isim,
                    tutar: taksit.taksitTutari,
                    odendiMi: taksit.odendiMi,
                    renk: kredi.renk
                )
                
                takvimGunleri[gun, default: []].append(detay)
            }
        }
        
        // Günleri OdemeTakvimGunu nesnelerine dönüştür ve sırala
        self.odemeTakvimiGunleri = takvimGunleri.map { (tarih, taksitler) in
            OdemeTakvimGunu(
                tarih: tarih,
                taksitler: taksitler,
                toplamTutar: taksitler.reduce(0) { $0 + $1.tutar }
            )
        }.sorted(by: { $0.tarih < $1.tarih })
    }
    
    private func prepareKrediKarsilastirmalari() async {
        var karsilastirmalar: [KrediKarsilastirma] = []
        
        for kredi in krediler {
            guard case .kredi(let cekilenTutar, let faizTipi, let faizOrani, let toplamTaksitSayisi, _, let taksitler) = kredi.detay else {
                continue
            }
            
            let kalanTaksitSayisi = taksitler.filter { !$0.odendiMi }.count
            let aylikTaksit = taksitler.first?.taksitTutari ?? 0
            let toplamKalanBorc = taksitler.filter { !$0.odendiMi }.reduce(0) { $0 + $1.taksitTutari }
            
            let karsilastirma = KrediKarsilastirma(
                krediAdi: kredi.isim,
                faizOrani: faizOrani,
                kalanTaksitSayisi: kalanTaksitSayisi,
                aylikYuk: aylikTaksit,
                toplamKalanBorc: toplamKalanBorc,
                renk: kredi.renk
            )
            
            karsilastirmalar.append(karsilastirma)
        }
        
        self.krediKarsilastirmalari = karsilastirmalar
    }
    
    private func calculateGeneralMetrics() {
        aktifKrediSayisi = krediler.count
        
        // Toplam kalan borç
        toplamKalanBorc = krediler.reduce(0) { total, kredi in
            guard case .kredi(_, _, _, _, _, let taksitler) = kredi.detay else {
                return total
            }
            let kalanBorc = taksitler.filter { !$0.odendiMi }.reduce(0) { $0 + $1.taksitTutari }
            return total + kalanBorc
        }
        
        // Bu dönemde ödenen toplam taksit
        toplamOdenenTaksit = krediTaksitOzetleri.reduce(0) { total, ozet in
            total + (ozet.toplamTaksitTutari * (Double(ozet.odenenTaksitSayisi) / Double(max(1, ozet.odenenTaksitSayisi + ozet.bekleyenTaksitSayisi))))
        }
    }
    
    // Tarihleri güncelleme fonksiyonu
    func updateDateRange(start: Date, end: Date) {
        self.baslangicTarihi = start
        self.bitisTarihi = end
        Task {
            await fetchData()
        }
    }
}
