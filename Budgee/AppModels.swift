import Foundation
import SwiftUI

// MARK: - App Navigation
public enum Sekme {
    case panel, takvim, raporlar, ayarlar
}

// MARK: - App Settings
class AppSettings: ObservableObject {
    @AppStorage("colorScheme") var colorSchemeValue: Int = 0
    @AppStorage("language") var languageCode: String = "tr"

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
}

public enum IslemTuru: String, Codable, CaseIterable {
    case gelir = "common.income"
    case gider = "common.expense"
    
    // YENİDEN EKLENDİ: Yerelleştirilmiş metni döndüren değişken
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

    // YENİDEN EKLENDİ: Yerelleştirilmiş metni döndüren değişken
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

    // YENİDEN EKLENDİ: Yerelleştirilmiş metni döndüren değişken
    var localized: String {
        NSLocalizedString(self.rawValue, comment: "")
    }
}

public enum TarihAraligi: String, Hashable, Identifiable {
    case hepsi = "enum.date_range.all"
    case buAy = "enum.date_range.this_month"
    case son3Ay = "enum.date_range.last_3_months"
    case son6Ay = "enum.date_range.last_6_months"
    case buYil = "enum.date_range.this_year"
    
    public var id: Self { self }
    
    // YENİDEN EKLENDİ: Yerelleştirilmiş metni döndüren değişken
    var localized: String {
        NSLocalizedString(self.rawValue, comment: "")
    }
    
    public static var allCases: [TarihAraligi] { [.hepsi, .buAy, .son3Ay, .son6Ay, .buYil] }
}

struct FiltreAyarlari {
    var tarihAraligi: TarihAraligi = .hepsi
    var secilenTurler: Set<IslemTuru> = [.gelir, .gider]
    var secilenKategoriler: Set<UUID> = []
    var sortOrder: SortOrder = .tarihAzalan
}
