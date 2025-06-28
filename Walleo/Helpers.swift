import Foundation
import SwiftUI

func colorFor(kategori: String) -> Color {
    let hash = abs(kategori.hashValue)
    let hue = fmod(Double(hash) * 0.61803398875, 1.0)
    return Color(hue: hue, saturation: 0.8, brightness: 0.9)
}

func iconFor(tekrar: TekrarTuru) -> String {
    switch tekrar {
    case .tekSeferlik: return "arrow.right.circle.fill"
    case .herAy: return "calendar"
    case .her3Ay, .her6Ay: return "calendar.circle"
    case .herYil: return "calendar.circle.fill"
    }
}

func formatDateForList(from date: Date, localeIdentifier: String) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "E, d MMM"
    // DEĞİŞİKLİK: Locale artık sabit değil, parametreden geliyor.
    formatter.locale = Locale(identifier: localeIdentifier)
    return formatter.string(from: date)
}

func monthYearString(from date: Date, localeIdentifier: String) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "MMMM yyyy"
    formatter.locale = Locale(identifier: localeIdentifier)
    return formatter.string(from: date)
}

// --- NİHAİ DÜZELTME BURADA ---
func formatCurrency(amount: Double, currencyCode: String, localeIdentifier: String) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.locale = Locale(identifier: localeIdentifier)
    formatter.currencyCode = currencyCode // Örn: "TRY"

    // Bu ayarlar, yerelleştirmeye uygun binlik ve ondalık ayraçlarının
    // her zaman doğru kullanılmasını garantiler.
    formatter.usesGroupingSeparator = true
    formatter.maximumFractionDigits = 2
    formatter.minimumFractionDigits = 2
    
    // Önce formatlayıcıdan temel string'i alalım (örn: "TRY1.500,50")
    guard var formattedString = formatter.string(from: NSNumber(value: amount)) else {
        return "\(amount) \(currencyCode)"
    }
    
    // Şimdi, bizim enum'ımızdan gelen "garantili" simgeyi alalım.
    if let currency = Currency(rawValue: currencyCode) {
        // Eğer formatlanmış string içinde ISO kodu (örn: "TRY") varsa,
        // onu bizim simgemizle ("₺") değiştir.
        // Bu, ingilizce locale'in "TRY" basmasını engeller.
        formattedString = formattedString.replacingOccurrences(of: currencyCode, with: currency.symbol)
    }
    
    return formattedString
}

func formatAmountForEditing(amount: Double, localeIdentifier: String) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal // .currency yerine .decimal kullanıyoruz ki para simgesi gelmesin.
    formatter.locale = Locale(identifier: localeIdentifier)
    formatter.usesGroupingSeparator = true // Binlik ayraçlarını etkinleştirir.
    formatter.maximumFractionDigits = 2
    formatter.minimumFractionDigits = 0 // Tamsayıları ondalıksız gösterebilir.
    
    // 0 ise boş string döndürerek placeholder'ın görünmesini sağlayabiliriz.
    // Ancak düzenleme ekranında 0'ın görünmesi daha doğru olabilir.
    if amount == 0 {
        return "0"
    }
    
    return formatter.string(from: NSNumber(value: amount)) ?? ""
}

func stringToDouble(_ stringValue: String, locale: Locale) -> Double {
    let groupingSeparator = locale.groupingSeparator ?? ""
    let decimalSeparator = locale.decimalSeparator ?? "."
    
    // 1. Adım: Metin içindeki tüm binlik ayraçlarını kaldır.
    // Örn: "1.234,56" -> "1234,56"
    let withoutGrouping = stringValue.replacingOccurrences(of: groupingSeparator, with: "")
    
    // 2. Adım: Dile özgü ondalık ayracını, Double() fonksiyonunun anlayacağı standart "." ile değiştir.
    // Örn: "1234,56" -> "1234.56"
    let parsableString = withoutGrouping.replacingOccurrences(of: decimalSeparator, with: ".")
    
    return Double(parsableString) ?? 0.0
}

func getLocalized(_ key: String, from appSettings: AppSettings) -> String {
    let languageCode = appSettings.languageCode
    
    // Doğru dil paketini (bundle) bul
    if let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
       let languageBundle = Bundle(path: path) {
        // Çeviriyi bu paketten al
        return languageBundle.localizedString(forKey: key, value: key, table: nil)
    }
    
    // Eğer bir sebepten dil paketi bulunamazsa, standart (genellikle İngilizce) çeviriyi dene.
    return NSLocalizedString(key, comment: "")
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// Bu kodu Helpers.swift veya View+Extensions.swift gibi genel bir dosyaya ekleyebilirsiniz.

// Bu extension, Swift'e her bir UUID'nin kendi kendisinin kimliği olduğunu söyler.
// Böylece SwiftUI'ın .sheet(item: ...) gibi fonksiyonları UUID ile sorunsuz çalışır.
extension UUID: @retroactive Identifiable {
    public var id: UUID { self }
}

