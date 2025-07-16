//
//  Transfer.swift
//  Walleo
//
//  Created by Mustafa Turan on 16.07.2025.
//


// Walleo/Core/Data/Transfer.swift
// Hesaplar arası transfer işlemlerini temsil eden veri modeli

import Foundation
import SwiftData

@Model
class Transfer {
    var id: UUID = UUID()
    var tutar: Double = 0.0
    var tarih: Date = Date()
    var aciklama: String = ""
    
    // İlişkiler
    @Relationship(deleteRule: .nullify)
    var kaynakHesap: Hesap?
    
    @Relationship(deleteRule: .nullify) 
    var hedefHesap: Hesap?
    
    init(tutar: Double, tarih: Date = Date(), aciklama: String = "", kaynakHesap: Hesap?, hedefHesap: Hesap?) {
        self.id = UUID()
        self.tutar = tutar
        self.tarih = tarih
        self.aciklama = aciklama
        self.kaynakHesap = kaynakHesap
        self.hedefHesap = hedefHesap
    }
}

// MARK: - Hesap Modelinde Eklenmesi Gereken İlişkiler
// Hesap.swift dosyasına aşağıdaki ilişkiler eklenmelidir:
/*
@Relationship(deleteRule: .nullify, inverse: \Transfer.kaynakHesap)
var gidenTransferler: [Transfer]? = []

@Relationship(deleteRule: .nullify, inverse: \Transfer.hedefHesap)
var gelenTransferler: [Transfer]? = []
*/