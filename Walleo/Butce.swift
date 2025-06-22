//
//  Butce.swift
//  Budgee
//
//  Created by Mustafa Turan on 22.06.2025.
//


import Foundation
import SwiftData

@Model
class Butce {
    @Attribute(.unique) var id: UUID
    var isim: String
    var limitTutar: Double
    var olusturmaTarihi: Date
    var tekrarAraligi: ButceTekrarAraligi

    // İLİŞKİ: Bir bütçe, birden fazla harcama kategorisini içerebilir.
    // Bu, "Yeme-İçme" gibi genel bir bütçenin hem "Market" hem de
    // "Restoran" kategorilerini kapsamasına olanak tanır.
    // Kategori silindiğinde bütçe silinmez, sadece ilişki kopar.
    @Relationship(deleteRule: .nullify)
    var kategoriler: [Kategori]?

    init(isim: String, limitTutar: Double, tekrarAraligi: ButceTekrarAraligi = .aylik, kategoriler: [Kategori] = []) {
        self.id = UUID()
        self.isim = isim
        self.limitTutar = limitTutar
        self.olusturmaTarihi = Date()
        self.tekrarAraligi = tekrarAraligi
        self.kategoriler = kategoriler
    }
}
