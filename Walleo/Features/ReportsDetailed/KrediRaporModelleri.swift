// Features/ReportsDetailed/Models/KrediRaporModelleri.swift

import Foundation
import SwiftUI

// MARK: - Ana Kredi Raporu Modeli
struct KrediGenelOzet {
    var aktifKrediSayisi: Int = 0
    var tamamlananKrediSayisi: Int = 0
    var toplamKrediTutari: Double = 0.0
    var toplamOdenenTutar: Double = 0.0
    var toplamKalanBorc: Double = 0.0
    var donemdekiToplamTaksitTutari: Double = 0.0
    var odenenToplamTaksitTutari: Double = 0.0
    var odenenTaksitSayisi: Int = 0
    var odenmeyenTaksitSayisi: Int = 0
    var aylikToplamTaksitYuku: Double = 0.0
    var ilerlemeYuzdesi: Double = 0.0
    var tahminiTamamlanmaTarihi: Date?
}

// MARK: - Kredi Detay Raporu
struct KrediDetayRaporu: Identifiable {
    let id: UUID
    let hesap: Hesap
    var krediDetaylari: KrediDetaylari?
    var donemdekiTaksitler: [KrediTaksitDetayi] = []
    var tumTaksitler: [KrediTaksitDetayi] = [] // DOĞRU YER - odemePerformansi'den ÖNCE
    var odemePerformansi: OdemePerformansi = OdemePerformansi()
    var sonrakiTaksit: KrediTaksitDetayi?
    var ilerlemeYuzdesi: Double = 0.0
    
    // Hesaplanan özellikler
    var donemdekiTaksitTutari: Double {
        donemdekiTaksitler.reduce(0) { $0 + $1.taksitTutari }
    }
    var odenenTaksitler: [KrediTaksitDetayi] {
        donemdekiTaksitler.filter { $0.odendiMi }
    }
    var odenmeyenTaksitler: [KrediTaksitDetayi] {
        donemdekiTaksitler.filter { !$0.odendiMi && $0.odemeTarihi < Date() }
    }
    var gelecekTaksitler: [KrediTaksitDetayi] {
        donemdekiTaksitler.filter { !$0.odendiMi && $0.odemeTarihi >= Date() }
    }
}

// MARK: - Kredi Detayları
struct KrediDetaylari {
    let cekilenTutar: Double
    let faizTipi: FaizTipi
    let faizOrani: Double
    let toplamTaksitSayisi: Int
    let ilkTaksitTarihi: Date
    let toplamOdenecekTutar: Double
    let toplamFaizTutari: Double
    var odenenTaksitSayisi: Int = 0
    var kalanTaksitSayisi: Int = 0
    var kalanAnaparaTutari: Double = 0.0
    var sonOdemeTarihi: Date?
    
    var aylikTaksitTutari: Double {
        toplamOdenecekTutar / Double(toplamTaksitSayisi)
    }
}

// MARK: - Ödeme Performansı
struct OdemePerformansi {
    var zamanindaOdenenSayisi: Int = 0
    var gecOdenenSayisi: Int = 0
    var odenmeyenSayisi: Int = 0
    var performansSkoru: Double = 0.0 // 0-100 arası
    
    var performansRengi: Color {
        switch performansSkoru {
        case 80...100: return .green
        case 60..<80: return .orange
        default: return .red
        }
    }
}

// MARK: - Kredi İstatistikleri
struct KrediIstatistikleri {
    var toplamOdenenFaiz: Double = 0.0
    var ortalamaGecikmeGunu: Double = 0.0
    var enBuyukTaksitTutari: Double = 0.0
    var enKucukTaksitTutari: Double = 0.0
    var aylikOrtalamaOdeme: Double = 0.0
}

// MARK: - Ödeme Takvimi
struct OdemeTakvimi {
    let ay: Date
    var taksitler: [TaksitOzeti] = []
    var toplamTutar: Double = 0.0
    
    struct TaksitOzeti: Identifiable {
        let id = UUID()
        let krediAdi: String
        let taksitNo: String
        let tutar: Double
        let odemeTarihi: Date
        let odendiMi: Bool
    }
}

// MARK: - Görünüm Türleri
enum KrediRaporGorunum: String, CaseIterable {
    case ozet = "loan_report.view.summary"
    case detay = "loan_report.view.detail"
    case takvim = "loan_report.view.calendar"
    case performans = "loan_report.view.performance"
    
    var icon: String {
        switch self {
        case .ozet: return "chart.pie.fill"
        case .detay: return "list.bullet.below.rectangle"
        case .takvim: return "calendar"
        case .performans: return "chart.line.uptrend.xyaxis"
        }
    }
}

// MARK: - Filtreleme Seçenekleri
struct KrediFiltre {
    var sadecekAktifler: Bool = true
    var siralama: KrediSiralama = .tariheGore
    var aramaMetni: String = ""
}

enum KrediSiralama: String, CaseIterable {
    case tariheGore = "loan_report.sort.by_date"
    case tutaraGore = "loan_report.sort.by_amount"
    case ilerlemeGore = "loan_report.sort.by_progress"
}
