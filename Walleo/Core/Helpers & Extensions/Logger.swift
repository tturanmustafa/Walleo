//
//  Logger.swift
//  Walleo
//
//  Created by Mustafa Turan on 24.06.2025.
//


import Foundation
import os.log

/// Uygulama genelinde standartlaştırılmış loglama yapmak için kullanılan yardımcı yapı.
struct Logger {
    /// Uygulamanın kimliği, logları Konsol uygulamasında filtrelemek için kullanılır.
    private static var subsystem = Bundle.main.bundleIdentifier!

    /// Veritabanı (SwiftData) işlemleriyle ilgili loglar için.
    static let data = OSLog(subsystem: subsystem, category: "Data")
    
    /// SwiftUI View'ları ve UI yaşam döngüsüyle ilgili loglar için.
    static let view = OSLog(subsystem: subsystem, category: "View")
    
    /// Servisler, yöneticiler ve iş mantığıyla ilgili loglar için.
    static let service = OSLog(subsystem: subsystem, category: "Service")
    
    /// Belirtilen kategori ve seviyede bir mesaj loglar.
    /// - Parameters:
    ///   - message: Loglanacak metin.
    ///   - log: `OSLog` nesnesi (örn: `Logger.data`).
    ///   - type: Log seviyesi (örn: `.error`, `.info`).
    static func log(_ message: String, log: OSLog = .default, type: OSLogType = .default) {
        // os_log, Apple'ın performanslı loglama fonksiyonudur.
        // %{public}s ifadesi, loglanan metnin Konsol'da gizlenmemesini sağlar.
        os_log("%{public}s", log: log, type: type, message)
    }
}
