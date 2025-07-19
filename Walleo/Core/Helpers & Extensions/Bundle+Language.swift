// Helpers/Bundle+Language.swift
import Foundation

extension Bundle {
    static func getLanguageBundle(for languageCode: String) -> Bundle {
        if let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle
        }
        // Eğer belirtilen dilde bir paket bulunamazsa, ana paketi kullan
        return .main
    }
}
