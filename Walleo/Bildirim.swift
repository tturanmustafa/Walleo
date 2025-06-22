//
//  BildirimTuru.swift
//  Walleo
//
//  Created by Mustafa Turan on 22.06.2025.
//


import Foundation
import SwiftData

// Uygulama içi bildirim türlerini tanımlayan enum.
// Bu sayede her bildirimin amacını ve ikonunu kolayca yönetebiliriz.
enum BildirimTuru: String, Codable {
    case butceLimitiYaklasti = "bütçe.limit.yaklaştı"
    case butceLimitiAsildi = "bütçe.limit.aşıldı"
    case taksitHatirlatici = "taksit.hatırlatıcı"
    case krediKartiOdemeGunu = "kart.ödeme.günü"
}


@Model
class Bildirim {
    @Attribute(.unique) var id: UUID
    
    // Bildirimin amacını belirten tür.
    var turRawValue: String
    
    // Bildirim listesinde gösterilecek başlık.
    var baslik: String
    
    // Bildirim listesinde başlığın altında görünecek daha detaylı açıklama.
    var aciklama: String
    
    // Bildirimin ne zaman oluşturulduğu.
    var olusturmaTarihi: Date
    
    // Kullanıcının bildirimi görüp görmediğini anlamak için.
    var okunduMu: Bool
    
    // Bildirime tıklandığında hangi detaya (bütçe, hesap vb.) gidileceğini
    // belirlemek için ilgili nesnenin ID'si.
    var hedefID: UUID?
    
    // 'turRawValue' string'ini daha güvenli bir şekilde kullanmak için
    // hesaplanmış değişken.
    var tur: BildirimTuru {
        get { BildirimTuru(rawValue: turRawValue) ?? .butceLimitiAsildi }
        set { turRawValue = newValue.rawValue }
    }
    
    init(tur: BildirimTuru, baslik: String, aciklama: String, hedefID: UUID? = nil) {
        self.id = UUID()
        self.turRawValue = tur.rawValue
        self.baslik = baslik
        self.aciklama = aciklama
        self.olusturmaTarihi = Date()
        self.okunduMu = false
        self.hedefID = hedefID
    }
}
