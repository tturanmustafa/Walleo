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
    @AppStorage("colorScheme") var colorSchemeValue: Int = 0
    @AppStorage("language") var languageCode: String = "tr"
    @AppStorage("currencyCode") var currencyCode: String = Currency.TRY.rawValue

    var colorScheme: ColorScheme? {
        switch colorSchemeValue {
        case 1: .light
        case 2: .dark
        default: nil
        }
    }
}

// MARK: - Data Structures for Views
struct KategoriHarcamasi: Identifiable {
    let id = UUID()
    var kategori: String
    var tutar: Double
    var renk: Color
    var localizationKey: String?
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

// MARK: - Filtering & Sorting Structures
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

// **************************************************
// DEĞİŞİKLİK BURADA: TarihAraligi enum'ı güncellendi.
// **************************************************
public enum TarihAraligi: String, Hashable, Identifiable {
    case hepsi = "enum.date_range.all"
    case buHafta = "enum.date_range.this_week"
    case buAy = "enum.date_range.this_month"
    case son3Ay = "enum.date_range.last_3_months"
    case son6Ay = "enum.date_range.last_6_months"
    case yilBasindanBeri = "enum.date_range.ytd"
    case sonYil = "enum.date_range.last_year"
    
    public var id: Self { self }
    
    var localized: String {
        NSLocalizedString(self.rawValue, comment: "")
    }
    
    public static var allCases: [TarihAraligi] {
        [.hepsi, .buHafta, .buAy, .son3Ay, .son6Ay, .yilBasindanBeri, .sonYil]
    }
}

struct FiltreAyarlari {
    var tarihAraligi: TarihAraligi = .hepsi
    var secilenTurler: Set<IslemTuru> = [.gelir, .gider]
    var secilenKategoriler: Set<UUID> = []
    var sortOrder: SortOrder = .tarihAzalan
}

// Bu bildirimi anlık veri güncellemesi için kullanıyoruz
extension Notification.Name {
    static let yeniIslemEklendi = Notification.Name("yeniIslemEklendi")
}
