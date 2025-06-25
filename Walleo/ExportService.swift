import Foundation
import SwiftData

class ExportService {
    
    // DÜZELTME: Fonksiyon artık ModelContext yerine, güvenli bir şekilde [Islem] dizisi ve dil kodu alıyor.
    static func generateCSV(from islemler: [Islem], languageCode: String) -> String {
        
        // DÜZELTME: Çevirileri yapmak için doğru dil paketini (bundle) buluyoruz.
        guard let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
              let languageBundle = Bundle(path: path) else {
            // Dil paketi bulunamazsa en azından İngilizce başlıklarla devam et.
            return "Date,Name,Amount,Type,Category,Account\n"
        }
        
        // DÜZELTME: Başlıkları artık lokalizasyon anahtarlarından çeviriyoruz.
        let headerDate = languageBundle.localizedString(forKey: "common.date", value: "Date", table: nil)
        let headerName = languageBundle.localizedString(forKey: "transaction.name_placeholder", value: "Name", table: nil)
        let headerAmount = languageBundle.localizedString(forKey: "common.amount", value: "Amount", table: nil)
        let headerType = languageBundle.localizedString(forKey: "common.type", value: "Type", table: nil)
        let headerCategory = languageBundle.localizedString(forKey: "common.category", value: "Category", table: nil)
        let headerAccount = languageBundle.localizedString(forKey: "common.account", value: "Account", table: nil)
        
        var csvString = "\(headerDate),\(headerName),\(headerAmount),\(headerType),\(headerCategory),\(headerAccount)\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        for islem in islemler {
            let tarih = dateFormatter.string(from: islem.tarih)
            let isim = escapeCSVString(islem.isim)
            let tutar = String(islem.tutar).replacingOccurrences(of: ",", with: ".")
            
            // DÜZELTME: 'common.expense' gibi anahtarlar yerine çevrilmiş metni alıyoruz.
            let tur = languageBundle.localizedString(forKey: islem.tur.rawValue, value: islem.tur.rawValue, table: nil)
            
            // DÜZELTME: Kategori için önce lokalizasyon anahtarını, yoksa ismini çeviriyoruz.
            let kategoriAdi = islem.kategori?.localizationKey ?? islem.kategori?.isim ?? "N/A"
            let kategori = escapeCSVString(languageBundle.localizedString(forKey: kategoriAdi, value: kategoriAdi, table: nil))

            let hesap = escapeCSVString(islem.hesap?.isim ?? "N/A")
            
            let row = "\(tarih),\(isim),\(tutar),\(tur),\(kategori),\(hesap)\n"
            csvString.append(row)
        }
        
        return csvString
    }
    
    private static func escapeCSVString(_ string: String) -> String {
        if string.contains(",") || string.contains("\"") || string.contains("\n") {
            let escapedString = string.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escapedString)\""
        }
        return string
    }
}
