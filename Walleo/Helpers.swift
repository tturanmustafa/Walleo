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

func formatCurrency(amount: Double, currencyCode: String, localeIdentifier: String) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.locale = Locale(identifier: localeIdentifier)
    formatter.currencyCode = currencyCode
    
    // Bu ayarlar, yerelleştirmeye uygun binlik ve ondalık ayraçlarının
    // her zaman doğru kullanılmasını garantiler.
    formatter.usesGroupingSeparator = true
    formatter.maximumFractionDigits = 2
    formatter.minimumFractionDigits = 2
    
    // Eğer formatlama başarısız olursa, en azından bir değer gösterelim.
    return formatter.string(from: NSNumber(value: amount)) ?? "\(amount) \(currencyCode)"
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
