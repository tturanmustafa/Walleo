// Dosya: BildirimModelleri.swift

import SwiftUI

// GÜNCELLEME: `aciklama` yerine üç ayrı satır eklendi.
struct BildirimDisplayContent {
    let baslik: String
    let aciklamaLine1: String
    let aciklamaLine2: String? // Opsiyonel, her bildirimde olmayabilir.
    let aciklamaLine3: String? // Opsiyonel
    let ikonAdi: String
    let ikonRengi: Color
}
