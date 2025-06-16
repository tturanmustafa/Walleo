import Foundation
import SwiftUI

// MARK: - App Navigation
public enum Sekme { // public yapıldı
    case panel, takvim, raporlar, ayarlar
}

// MARK: - App Settings
class AppSettings: ObservableObject {
    @AppStorage("colorScheme") var colorSchemeValue: Int = 0

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

public enum IslemTuru: String, Codable, CaseIterable { // public yapıldı
    case gelir = "Gelir"
    case gider = "Gider"
}

public enum TekrarTuru: String, CaseIterable, Identifiable, Codable { // public yapıldı
    case tekSeferlik = "Tek Seferlik", herAy = "Her Ay", her3Ay = "Her 3 Ayda Bir", her6Ay = "Her 6 Ayda Bir", herYil = "Her Yıl"
    public var id: String { self.rawValue }
}

// MARK: - Filtering & Sorting Structures
public enum SortOrder: String, CaseIterable, Identifiable { // public yapıldı
    case tarihAzalan = "Tarihe Göre (Yeniden)", tarihArtan = "Tarihe Göre (Eskiden)", tutarAzalan = "Tutara Göre (Çoktan)", tutarArtan = "Tutara Göre (Azdan)"
    public var id: String { self.rawValue }
}

public enum TarihAraligi: Hashable, Identifiable { // public yapıldı
    case hepsi, buAy, son3Ay, son6Ay, buYil
    public var id: Self { self }
    public var name: String {
        switch self {
        case .hepsi: "Tüm Zamanlar"
        case .buAy: "Bu Ay"
        case .son3Ay: "Son 3 Ay"
        case .son6Ay: "Son 6 Ay"
        case .buYil: "Bu Yıl"
        }
    }
    public static var allCases: [TarihAraligi] { [.hepsi, .buAy, .son3Ay, .son6Ay, .buYil] }
}

struct FiltreAyarlari {
    var tarihAraligi: TarihAraligi = .hepsi
    var secilenTurler: Set<IslemTuru> = [.gelir, .gider]
    var secilenKategoriler: Set<UUID> = [] // <-- EN KRİTİK DEĞİŞİKLİK: Kategori.ID'den UUID'ye
    var sortOrder: SortOrder = .tarihAzalan
}
