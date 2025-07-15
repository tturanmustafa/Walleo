import Foundation
import SwiftUI

// MARK: - App Navigation
public enum Sekme {
    case panel, takvim, raporlar, ayarlar
}

// YENİ: Desteklenen para birimlerini tanımlayan genişletilmiş enum
public enum Currency: String, CaseIterable, Identifiable {
    case TRY, USD, EUR, GBP, JPY, CAD, AUD, CHF, CNY, SEK, NOK, RUB, INR, BRL, ZAR, AED, SAR, KRW, SGD

    public var id: String { self.rawValue }

    var symbol: String {
        switch self {
        case .TRY: return "₺"
        case .USD: return "$"
        case .EUR: return "€"
        case .GBP: return "£"
        case .JPY: return "¥"
        case .CAD: return "CA$"
        case .AUD: return "A$"
        case .CHF: return "CHF"
        case .CNY: return "CN¥"
        case .SEK: return "kr"
        case .NOK: return "kr"
        case .RUB: return "₽"
        case .INR: return "₹"
        case .BRL: return "R$"
        case .ZAR: return "R"
        case .AED: return "د.إ"
        case .SAR: return "﷼"
        case .KRW: return "₩"
        case .SGD: return "S$"
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
    @AppStorage("language") var languageCode: String = "tr"
    @AppStorage("currencyCode") var currencyCode: String = Currency.TRY.rawValue
    @AppStorage("isCloudKitEnabled") var isCloudKitEnabled: Bool = true
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding: Bool = false



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
