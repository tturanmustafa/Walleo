// Walleo/Core/Data/Kategori.swift
import Foundation
import SwiftData
import SwiftUI

// YENİ: Sistem kategorileri için sabit UUID'ler
struct SystemCategoryIDs {
    static let salary = UUID(uuidString: "A1B2C3D4-E5F6-7890-ABCD-EF1234567890")!
    static let extraIncome = UUID(uuidString: "A1B2C3D4-E5F6-7890-ABCD-EF1234567891")!
    static let investment = UUID(uuidString: "A1B2C3D4-E5F6-7890-ABCD-EF1234567892")!
    static let groceries = UUID(uuidString: "A1B2C3D4-E5F6-7890-ABCD-EF1234567893")!
    static let restaurant = UUID(uuidString: "A1B2C3D4-E5F6-7890-ABCD-EF1234567894")!
    static let transport = UUID(uuidString: "A1B2C3D4-E5F6-7890-ABCD-EF1234567895")!
    static let bills = UUID(uuidString: "A1B2C3D4-E5F6-7890-ABCD-EF1234567896")!
    static let entertainment = UUID(uuidString: "A1B2C3D4-E5F6-7890-ABCD-EF1234567897")!
    static let health = UUID(uuidString: "A1B2C3D4-E5F6-7890-ABCD-EF1234567898")!
    static let clothing = UUID(uuidString: "A1B2C3D4-E5F6-7890-ABCD-EF1234567899")!
    static let home = UUID(uuidString: "A1B2C3D4-E5F6-7890-ABCD-EF1234567900")!
    static let gift = UUID(uuidString: "A1B2C3D4-E5F6-7890-ABCD-EF1234567901")!
    static let loanPayment = UUID(uuidString: "A1B2C3D4-E5F6-7890-ABCD-EF1234567902")!
    static let other = UUID(uuidString: "A1B2C3D4-E5F6-7890-ABCD-EF1234567903")!
    
    // Tüm sistem kategori ID'lerini içeren array
    static let allIDs: [UUID] = [
        salary, extraIncome, investment, groceries, restaurant,
        transport, bills, entertainment, health, clothing,
        home, gift, loanPayment, other
    ]
}

@Model
class Kategori {
    var id: UUID = UUID()
    var isim: String = ""
    var ikonAdi: String = ""
    var renkHex: String = ""
    var localizationKey: String?
    var turRawValue: String = IslemTuru.gider.rawValue
    var olusturmaTarihi: Date = Date()

    @Relationship(deleteRule: .nullify, inverse: \Islem.kategori)
    var islemler: [Islem]?
    
    @Relationship(inverse: \Butce.kategoriler)
    var butceler: [Butce]?
    
    var tur: IslemTuru {
        get { IslemTuru(rawValue: turRawValue) ?? .gider }
        set { turRawValue = newValue.rawValue }
    }
    
    var renk: Color { Color(hex: renkHex) }
    
    // Kategori.swift init fonksiyonundaki logger satırını değiştir
    init(id: UUID = UUID(), isim: String, ikonAdi: String, tur: IslemTuru, renkHex: String, localizationKey: String? = nil) {
        self.id = id
        self.isim = isim
        self.ikonAdi = ikonAdi
        self.renkHex = renkHex
        self.localizationKey = localizationKey
        self.turRawValue = tur.rawValue
        self.olusturmaTarihi = Date()
        
        // SORUNLU SATIR:
        // Logger.log("Kategori oluşturuluyor: \(isim)", log: Logger.data)
        
        // DÜZELTME - Logger satırını tamamen kaldırın veya basitleştirin:
        if localizationKey != nil {
            Logger.log("Sistem kategorisi oluşturuluyor", log: Logger.data)
        }
    }
}
