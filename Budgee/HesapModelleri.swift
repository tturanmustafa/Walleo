//
//  KrediKartiHesaplananDetay.swift
//  Budgee
//
//  Created by Mustafa Turan on 19.06.2025.
//


// MARK: - DOSYA: HesapModelleri.swift
import Foundation
import SwiftUI

struct KrediKartiHesaplananDetay: Hashable {
    var guncelBorc: Double
    var kullanilabilirLimit: Double
}

struct KrediHesaplananDetay: Hashable {
    var kalanTaksitSayisi: Int
    var odenenTaksitSayisi: Int
}

struct GosterilecekHesap: Identifiable, Hashable {
    let hesap: Hesap
    var guncelBakiye: Double
    var krediKartiDetay: KrediKartiHesaplananDetay?
    var krediDetay: KrediHesaplananDetay?
    var id: UUID { hesap.id }
}