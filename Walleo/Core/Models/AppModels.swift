import Foundation
import SwiftUI

// MARK: - App Navigation
public enum Sekme {
    case panel, takvim, raporlar, ayarlar
}

// YENİ: Desteklenen para birimlerini tanımlayan genişletilmiş enum
public enum Currency: String, CaseIterable, Identifiable {
    // Major Currencies
    case USD, EUR, GBP, JPY, CNY, CHF
    
    // Asia-Pacific
    case AUD, NZD, HKD, SGD, TWD, KRW, INR, PKR, BDT, LKR, NPR, MMK, LAK, KHR
    case THB, VND, IDR, MYR, PHP, BND
    
    // Middle East & Africa
    case AED, SAR, QAR, OMR, BHD, KWD, JOD, ILS, EGP, MAD, TND, DZD
    case ZAR, KES, UGX, TZS, ETB, GHS, NGN, XOF, XAF
    
    // Europe
    case SEK, NOK, DKK, ISK, PLN, CZK, HUF, RON, BGN, HRK, RSD, MKD, ALL, BAM
    case UAH, BYN, MDL, GEL, AMD, AZN
    
    // Americas
    case CAD, MXN, BRL, ARS, CLP, COP, PEN, UYU, PYG, BOB, VES
    case CRC, GTQ, HNL, NIO, PAB, DOP, JMD, TTD, BBD, BSD, HTG, XCD
    
    // Turkey & Central Asia
    case TRY, KZT, UZS, KGS, TJS, TMT, AFN, MNT
    
    // Pacific Islands
    case FJD, PGK, SBD, TOP, VUV, WST, XPF
    
    // Others
    case RUB, IRR, IQD, SYP, YER, LBP, MZN, AOA, MGA, MUR, SCR, MVR, BTN

    public var id: String { self.rawValue }

    var symbol: String {
        switch self {
        // Major
        case .USD: return "$"
        case .EUR: return "€"
        case .GBP: return "£"
        case .JPY: return "¥"
        case .CNY: return "¥"
        case .CHF: return "Fr"
        
        // Dollar variants
        case .AUD: return "A$"
        case .CAD: return "C$"
        case .HKD: return "HK$"
        case .NZD: return "NZ$"
        case .SGD: return "S$"
        case .TWD: return "NT$"
        case .MXN: return "Mex$"
        case .BBD: return "Bds$"
        case .BSD: return "B$"
        case .JMD: return "J$"
        case .TTD: return "TT$"
        case .XCD: return "EC$"
        case .FJD: return "FJ$"
        case .SBD: return "SI$"
        
        // Unique symbols
        case .TRY: return "₺"
        case .INR: return "₹"
        case .PKR: return "₨"
        case .NPR: return "रू"
        case .LKR: return "රු"
        case .BDT: return "৳"
        case .THB: return "฿"
        case .KRW: return "₩"
        case .VND: return "₫"
        case .PHP: return "₱"
        case .IDR: return "Rp"
        case .MYR: return "RM"
        case .LAK: return "₭"
        case .KHR: return "៛"
        case .MMK: return "K"
        case .BND: return "B$"
        
        // Middle East
        case .AED: return "د.إ"
        case .SAR: return "﷼"
        case .QAR: return "ر.ق"
        case .OMR: return "ر.ع"
        case .BHD: return "د.ب"
        case .KWD: return "د.ك"
        case .JOD: return "د.أ"
        case .ILS: return "₪"
        case .EGP: return "E£"
        case .LBP: return "ل.ل"
        case .SYP: return "£S"
        case .IQD: return "ع.د"
        case .YER: return "﷼"
        case .IRR: return "﷼"
        
        // Africa
        case .ZAR: return "R"
        case .MAD: return "د.م"
        case .TND: return "د.ت"
        case .DZD: return "د.ج"
        case .NGN: return "₦"
        case .GHS: return "₵"
        case .KES: return "Ksh"
        case .UGX: return "USh"
        case .TZS: return "TSh"
        case .ETB: return "Br"
        case .XOF: return "CFA"
        case .XAF: return "FCFA"
        case .MZN: return "MT"
        case .AOA: return "Kz"
        case .MGA: return "Ar"
        case .MUR: return "₨"
        case .SCR: return "₨"
        case .MVR: return "Rf"
        
        // Europe
        case .PLN: return "zł"
        case .CZK: return "Kč"
        case .HUF: return "Ft"
        case .RON: return "lei"
        case .BGN: return "лв"
        case .HRK: return "kn"
        case .RSD: return "дин"
        case .MKD: return "ден"
        case .ALL: return "L"
        case .BAM: return "KM"
        case .UAH: return "₴"
        case .BYN: return "Br"
        case .MDL: return "L"
        case .GEL: return "₾"
        case .AMD: return "֏"
        case .AZN: return "₼"
        case .RUB: return "₽"
        case .SEK: return "kr"
        case .NOK: return "kr"
        case .DKK: return "kr"
        case .ISK: return "kr"
        
        // Americas
        case .BRL: return "R$"
        case .ARS: return "$"
        case .CLP: return "$"
        case .COP: return "$"
        case .PEN: return "S/"
        case .UYU: return "$U"
        case .PYG: return "₲"
        case .BOB: return "Bs"
        case .VES: return "Bs"
        case .CRC: return "₡"
        case .GTQ: return "Q"
        case .HNL: return "L"
        case .NIO: return "C$"
        case .PAB: return "B/"
        case .DOP: return "RD$"
        case .HTG: return "G"
        
        // Central Asia
        case .KZT: return "₸"
        case .UZS: return "сўм"
        case .KGS: return "с"
        case .TJS: return "ЅМ"
        case .TMT: return "m"
        case .AFN: return "؋"
        case .MNT: return "₮"
        case .BTN: return "Nu."
        
        // Pacific
        case .PGK: return "K"
        case .TOP: return "T$"
        case .VUV: return "Vt"
        case .WST: return "T"
        case .XPF: return "₣"
        }
    }
    
    var localizedNameKey: String {
        return "currency.name.\(self.rawValue)"
    }
}

// MARK: - App Settings
class AppSettings: ObservableObject {
    // MARK: - General Settings
    @AppStorage("colorScheme") var colorSchemeValue: Int = 0
    @AppStorage("language") var languageCode: String = "en" // "tr" olan değeri "en" olarak değiştirin
    @AppStorage("currencyCode") var currencyCode: String = Currency.TRY.rawValue
    @AppStorage("isCloudKitEnabled") var isCloudKitEnabled: Bool = true
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding: Bool = false
    @AppStorage("notifications_credit_card_reminders_enabled") var creditCardRemindersEnabled: Bool = true
    @AppStorage("notifications_credit_card_reminder_days") var creditCardReminderDays: Int = 5



    var colorScheme: ColorScheme? {
        switch colorSchemeValue {
        case 1: .light
        case 2: .dark
        default: nil
        }
    }
    
    // MARK: - Notification Settings
    
    /// Tüm bildirimleri açıp kapatan ana anahtar.
    @AppStorage("notifications_master_enabled") var masterNotificationsEnabled: Bool = true
    
    /// Bütçe ile ilgili uyarıların açık olup olmadığını kontrol eder.
    @AppStorage("notifications_budget_alerts_enabled") var budgetAlertsEnabled: Bool = true
    
    /// Bütçe limiti yaklaşım uyarısının hangi oranda tetikleneceğini belirler (örn: 0.90 = %90).
    @AppStorage("notifications_budget_threshold") var budgetAlertThreshold: Double = 0.90
    
    /// Kredi taksidi hatırlatıcılarının açık olup olmadığını kontrol eder.
    @AppStorage("notifications_loan_reminders_enabled") var loanRemindersEnabled: Bool = true
    
    /// Kredi taksidi hatırlatıcısının vadeden kaç gün önce gönderileceğini belirler.
    @AppStorage("notifications_loan_reminder_days") var loanReminderDays: Int = 3
}

// MARK: - Data Structures for Views
struct KategoriHarcamasi: Identifiable {
    let id = UUID()
    var kategori: String
    var tutar: Double
    var renk: Color
    var localizationKey: String?
    var ikonAdi: String = "tag.fill"
}

public enum IslemTuru: String, Codable, CaseIterable {
    case gelir = "common.income"
    case gider = "common.expense"
    
    var localized: String {
        NSLocalizedString(self.rawValue, comment: "")
    }
}

public enum TekrarTuru: String, CaseIterable, Identifiable, Codable {
    case tekSeferlik = "enum.recurrence.once"
    case herAy = "enum.recurrence.monthly"
    case her3Ay = "enum.recurrence.quarterly"
    case her6Ay = "enum.recurrence.semi_annually"
    case herYil = "enum.recurrence.annually"
    
    public var id: String { self.rawValue }

    var localized: String {
        NSLocalizedString(self.rawValue, comment: "")
    }
}

public enum SortOrder: String, CaseIterable, Identifiable {
    case tarihAzalan = "enum.sort.date_desc"
    case tarihArtan = "enum.sort.date_asc"
    case tutarAzalan = "enum.sort.amount_desc"
    case tutarArtan = "enum.sort.amount_asc"
    
    public var id: String { self.rawValue }

    var localized: String {
        NSLocalizedString(self.rawValue, comment: "")
    }
}

public enum TarihAraligi: String, Hashable, Identifiable {
    case buHafta = "enum.date_range.this_week"
    case buAy = "enum.date_range.this_month"
    case son3Ay = "enum.date_range.last_3_months"
    case son6Ay = "enum.date_range.last_6_months"
    case yilBasindanBeri = "enum.date_range.ytd"
    case sonYil = "enum.date_range.last_year"
    case ozel = "enum.date_range.custom"
    
    public var id: Self { self }
    
    var localized: String { NSLocalizedString(self.rawValue, comment: "") }
    
    public static var allCases: [TarihAraligi] {
        [.buHafta, .buAy, .son3Ay, .son6Ay, .yilBasindanBeri, .sonYil, .ozel]
    }
}

struct FiltreAyarlari {
    var tarihAraligi: TarihAraligi = .buAy
    var secilenTurler: Set<IslemTuru> = [.gelir, .gider]
    var secilenKategoriler: Set<UUID> = []
    var secilenHesaplar: Set<UUID> = [] // <-- BU SATIRI EKLEYİN
    var sortOrder: SortOrder = .tarihAzalan
    var baslangicTarihi: Date? = nil
    var bitisTarihi: Date? = nil
}

extension Notification.Name {
    static let transactionsDidChange = Notification.Name("transactionsDidChange")
}

extension Notification.Name {
    // Mevcut olanın altına yenisini ekliyoruz.
    static let categoriesDidChange = Notification.Name("categoriesDidChange")
}

extension Notification.Name {
    // Mevcut olanın altına yenisini ekliyoruz.
    static let accountDetailsDidChange = Notification.Name("accountDetailsDidChange")
}

extension Date: @retroactive Identifiable {
    public var id: Date { self }
}


// Dosya: AppModels.swift -> Sadece bu extension'ı güncelleyin

extension TarihAraligi {
    // NİHAİ HAL: Bu fonksiyon teknik olarak doğru aralıkları döndürür.
    // Örn: Haziran ayı için bitiş tarihi 1 Temmuz 00:00'dır.
    func dateInterval() -> DateInterval? {
        let calendar = Calendar.current
        let now = Date()
        
        switch self {
        case .buHafta:
            return calendar.dateInterval(of: .weekOfYear, for: now)
        case .buAy:
            return calendar.dateInterval(of: .month, for: now)
        case .son3Ay:
            guard let baslangic = calendar.date(byAdding: .month, value: -3, to: now) else { return nil }
            return DateInterval(start: calendar.startOfDay(for: baslangic), end: now)
        case .son6Ay:
            guard let baslangic = calendar.date(byAdding: .month, value: -6, to: now) else { return nil }
            return DateInterval(start: calendar.startOfDay(for: baslangic), end: now)
        case .yilBasindanBeri:
            guard let yilinBasi = calendar.date(from: calendar.dateComponents([.year], from: now)) else { return nil }
            return DateInterval(start: yilinBasi, end: now)
        case .sonYil:
            guard let baslangic = calendar.date(byAdding: .year, value: -1, to: now) else { return nil }
            return DateInterval(start: calendar.startOfDay(for: baslangic), end: now)
        case .ozel:
            return nil
        }
    }
}

extension DateInterval {
    func previous() -> DateInterval {
        let calendar = Calendar.current
        let duration = calendar.dateComponents([.year, .month, .weekOfYear, .day], from: start, to: end)
        var invertedDuration = DateComponents()
        invertedDuration.year = -(duration.year ?? 0)
        invertedDuration.month = -(duration.month ?? 0)
        invertedDuration.weekOfYear = -(duration.weekOfYear ?? 0)
        invertedDuration.day = -(duration.day ?? 0)
        guard let previousStart = calendar.date(byAdding: invertedDuration, to: start) else {
            return self
        }
        let previousEnd = start
        return DateInterval(start: previousStart, end: previousEnd)
    }
}

extension Notification.Name {
    static let appShouldRestart = Notification.Name("appShouldRestart")
}

enum ButceTekrarAraligi: String, Codable, CaseIterable {
    case aylik = "enum.budget_period.monthly"
}

struct GosterilecekButce: Identifiable {
    let butce: Butce
    var harcananTutar: Double
    var id: UUID { butce.id }
}

struct TransactionChangePayload {
    /// Değişikliğin türü (ekleme, güncelleme, silme).
    enum ChangeType { case add, update, delete }
    
    let type: ChangeType
    let affectedAccountIDs: [UUID]
    let affectedCategoryIDs: [UUID]
}
