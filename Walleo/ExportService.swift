import Foundation
import SwiftData

class ExportService {
    
    static func generateCSV(from islemler: [Islem], languageCode: String) -> String {
        
        guard let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
              let languageBundle = Bundle(path: path) else {
            return "Date,Name,Amount,Type,Category,Account\n"
        }
        
        let headerDate = languageBundle.localizedString(forKey: "export.header.date", value: "Date", table: nil)
        let headerName = languageBundle.localizedString(forKey: "export.header.name", value: "Transaction Name", table: nil)
        let headerAmount = languageBundle.localizedString(forKey: "export.header.amount", value: "Amount", table: nil)
        let headerType = languageBundle.localizedString(forKey: "export.header.type", value: "Type", table: nil)
        let headerCategory = languageBundle.localizedString(forKey: "export.header.category", value: "Category", table: nil)
        let headerAccount = languageBundle.localizedString(forKey: "export.header.account", value: "Account", table: nil)
        
        var csvString = "\(headerDate),\(headerName),\(headerAmount),\(headerType),\(headerCategory),\(headerAccount)\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        let amountFormatter = NumberFormatter()
        amountFormatter.numberStyle = .decimal
        amountFormatter.minimumFractionDigits = 2
        amountFormatter.maximumFractionDigits = 2
        amountFormatter.groupingSeparator = "" // CSV verisinde binlik ayracı olmamalıdır.
        amountFormatter.decimalSeparator = "."   // NİHAİ DÜZELTME: Evrensel uyumluluk için ondalık ayracını noktaya sabitliyoruz.
        
        for islem in islemler {
            let tarih = dateFormatter.string(from: islem.tarih)
            let isim = escapeCSVString(islem.isim)
            
            // Tutar artık her zaman '.' ondalık ayracı ile formatlanacak.
            let tutar = amountFormatter.string(from: NSNumber(value: islem.tutar)) ?? "0.00"
            
            let tur = languageBundle.localizedString(forKey: islem.tur.rawValue, value: islem.tur.rawValue, table: nil)
            
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
