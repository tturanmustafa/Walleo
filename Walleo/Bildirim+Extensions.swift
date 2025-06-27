// Dosya: Bildirim+Extensions.swift

import SwiftUI

// Bildirim modeline, kendini ekranda nasıl göstereceğini "bilme" yeteneği ekliyoruz.
extension Bildirim {
    
    func displayContent(using appSettings: AppSettings) -> BildirimDisplayContent {
        let dilKodu = appSettings.languageCode
        let paraKodu = appSettings.currencyCode
        
        guard let path = Bundle.main.path(forResource: dilKodu, ofType: "lproj"),
              let languageBundle = Bundle(path: path) else {
            // GÜNCELLEME: Hata durumu da yeni yapıya uygun hale getirildi.
            return .init(baslik: "Hata", aciklamaLine1: "Dil dosyası yüklenemedi.", aciklamaLine2: nil, aciklamaLine3: nil, ikonAdi: "exclamationmark.circle", ikonRengi: .red)
        }
        
        var baslik: String
        var aciklamaLine1: String
        var aciklamaLine2: String?
        var aciklamaLine3: String?
        var ikonAdi: String
        var ikonRengi: Color

        switch self.tur {
        case .butceLimitiAsildi:
            baslik = languageBundle.localizedString(forKey: "notification.budget.over_limit.title", value: "Budget Exceeded", table: nil)
            let butceAdi = self.ilgiliIsim ?? ""
            let limit = formatCurrency(amount: self.tutar1 ?? 0, currencyCode: paraKodu, localeIdentifier: dilKodu)
            let asim = formatCurrency(amount: self.tutar2 ?? 0, currencyCode: paraKodu, localeIdentifier: dilKodu)
            
            aciklamaLine1 = String(format: languageBundle.localizedString(forKey: "notification.budget.over_limit.body_line1_format", value: "", table: nil), butceAdi)
            aciklamaLine2 = String(format: languageBundle.localizedString(forKey: "notification.budget.over_limit.body_line2", value: "", table: nil), limit)
            aciklamaLine3 = String(format: languageBundle.localizedString(forKey: "notification.budget.over_limit.body_line3", value: "", table: nil), asim)
            
            ikonAdi = "exclamationmark.circle.fill"
            ikonRengi = .red

        case .butceLimitiYaklasti:
            baslik = languageBundle.localizedString(forKey: "notification.budget.approaching_limit.title", value: "Budget Limit Approaching", table: nil)
            let butceAdi = self.ilgiliIsim ?? ""
            let limitValue = self.tutar1 ?? 0
            let yuzdeValue = self.tutar2 ?? 0
            let harcanan = limitValue * yuzdeValue
            let kalan = limitValue - harcanan
            
            let limitFormatted = formatCurrency(amount: limitValue, currencyCode: paraKodu, localeIdentifier: dilKodu)
            let kalanFormatted = formatCurrency(amount: kalan, currencyCode: paraKodu, localeIdentifier: dilKodu)
            
            aciklamaLine1 = String(format: languageBundle.localizedString(forKey: "notification.budget.approaching_limit.body_line1_format", value: "", table: nil), butceAdi, yuzdeValue * 100)
            aciklamaLine2 = String(format: languageBundle.localizedString(forKey: "notification.budget.approaching_limit.body_line2", value: "", table: nil), limitFormatted)
            aciklamaLine3 = String(format: languageBundle.localizedString(forKey: "notification.budget.approaching_limit.body_line3", value: "", table: nil), kalanFormatted)
            
            ikonAdi = "exclamationmark.triangle.fill"
            ikonRengi = .orange
            
        // GÜNCELLEME: Kredi Kartı durumu yeni yapıya uygun hale getirildi.
        case .krediKartiOdemeGunu:
            baslik = languageBundle.localizedString(forKey: "notification.credit_card.due_date.title", value: "Credit Card Payment Due", table: nil)
            let formatString = languageBundle.localizedString(forKey: "notification.credit_card.due_date.body_format", value: "", table: nil)
            let kartAdi = self.ilgiliIsim ?? ""
            let formatStyle = Date.FormatStyle(date: .long, time: .omitted, locale: Locale(identifier: dilKodu))
            let odemeGunu = self.tarih1?.formatted(formatStyle) ?? ""
            aciklamaLine1 = String(format: formatString, kartAdi, odemeGunu)
            // Bu bildirim tek satırlı olduğu için diğerleri nil.
            aciklamaLine2 = nil
            aciklamaLine3 = nil
            
            ikonAdi = "creditcard.circle.fill"
            ikonRengi = .purple
            
        // GÜNCELLEME: Varsayılan durum yeni yapıya uygun hale getirildi.
        default:
            baslik = "Bilinmeyen Bildirim"
            aciklamaLine1 = "Detay yok."
            aciklamaLine2 = nil
            aciklamaLine3 = nil
            ikonAdi = "questionmark.circle"
            ikonRengi = .gray
        }
        
        return .init(baslik: baslik, aciklamaLine1: aciklamaLine1, aciklamaLine2: aciklamaLine2, aciklamaLine3: aciklamaLine3, ikonAdi: ikonAdi, ikonRengi: ikonRengi)
    }
}
