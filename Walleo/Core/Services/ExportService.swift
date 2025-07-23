// ExportService.swift
import Foundation
import SwiftData

class ExportService {
    
    // Ana export fonksiyonu - ZIP içinde birden fazla CSV döndürür
    static func generateExportZip(
        islemler: [Islem],
        transferler: [Transfer],
        hesaplar: [Hesap],
        languageCode: String
    ) -> URL? {
        
        guard let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
              let languageBundle = Bundle(path: path) else {
            return nil
        }
        
        var csvFiles: [URL] = []
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        
        do {
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            
            // 1. Tüm İşlemler CSV
            let allTransactionsCSV = generateAllTransactionsCSV(islemler: islemler, bundle: languageBundle)
            let allTransactionsFileName = languageBundle.localizedString(forKey: "export.filename.all_transactions", value: "All_Transactions", table: nil)
            let allTransactionsFile = tempDir.appendingPathComponent("1_\(allTransactionsFileName).csv")
            try allTransactionsCSV.write(to: allTransactionsFile, atomically: true, encoding: .utf8)
            csvFiles.append(allTransactionsFile)
            
            // 2. Taksitli İşlemler CSV
            let taksitliIslemler = islemler.filter { $0.taksitliMi }
            if !taksitliIslemler.isEmpty {
                let installmentsCSV = generateInstallmentsCSV(islemler: taksitliIslemler, bundle: languageBundle)
                let installmentsFileName = languageBundle.localizedString(forKey: "export.filename.installments", value: "Installments", table: nil)
                let installmentsFile = tempDir.appendingPathComponent("2_\(installmentsFileName).csv")
                try installmentsCSV.write(to: installmentsFile, atomically: true, encoding: .utf8)
                csvFiles.append(installmentsFile)
            }
            
            // 3. Tekrarlı İşlemler CSV
            let tekrarliIslemler = islemler.filter { $0.tekrar != .tekSeferlik }
            if !tekrarliIslemler.isEmpty {
                let recurringCSV = generateRecurringCSV(islemler: tekrarliIslemler, bundle: languageBundle)
                let recurringFileName = languageBundle.localizedString(forKey: "export.filename.recurring", value: "Recurring", table: nil)
                let recurringFile = tempDir.appendingPathComponent("3_\(recurringFileName).csv")
                try recurringCSV.write(to: recurringFile, atomically: true, encoding: .utf8)
                csvFiles.append(recurringFile)
            }
            
            // 4. Transferler CSV
            if !transferler.isEmpty {
                let transfersCSV = generateTransfersCSV(transferler: transferler, bundle: languageBundle)
                let transfersFileName = languageBundle.localizedString(forKey: "export.filename.transfers", value: "Transfers", table: nil)
                let transfersFile = tempDir.appendingPathComponent("4_\(transfersFileName).csv")
                try transfersCSV.write(to: transfersFile, atomically: true, encoding: .utf8)
                csvFiles.append(transfersFile)
            }
            
            // 5. Krediler CSV
            let krediler = hesaplar.filter { hesap in
                if case .kredi = hesap.detay { return true }
                return false
            }
            if !krediler.isEmpty {
                let loansCSV = generateLoansCSV(krediler: krediler, bundle: languageBundle)
                let loansFileName = languageBundle.localizedString(forKey: "export.filename.loans", value: "Loans", table: nil)
                let loansFile = tempDir.appendingPathComponent("5_\(loansFileName).csv")
                try loansCSV.write(to: loansFile, atomically: true, encoding: .utf8)
                csvFiles.append(loansFile)
                
                // 6. Kredi Taksitleri CSV
                let loanInstallmentsCSV = generateLoanInstallmentsCSV(krediler: krediler, bundle: languageBundle)
                let loanInstallmentsFileName = languageBundle.localizedString(forKey: "export.filename.loan_installments", value: "Loan_Installments", table: nil)
                let loanInstallmentsFile = tempDir.appendingPathComponent("6_\(loanInstallmentsFileName).csv")
                try loanInstallmentsCSV.write(to: loanInstallmentsFile, atomically: true, encoding: .utf8)
                csvFiles.append(loanInstallmentsFile)
            }
            
            // ZIP dosyası oluştur
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd_HHmmss"
            let timestamp = dateFormatter.string(from: Date())
            let zipFile = FileManager.default.temporaryDirectory.appendingPathComponent("Walleo_Export_\(timestamp).zip")
            
            try FileManager.default.zipFiles(at: csvFiles, to: zipFile)
            
            // Temp dosyaları temizle
            try FileManager.default.removeItem(at: tempDir)
            
            return zipFile
            
        } catch {
            Logger.log("Export ZIP oluşturma hatası: \(error)", log: Logger.service, type: .error)
            return nil
        }
    }
    
    // 1. Tüm İşlemler CSV
    private static func generateAllTransactionsCSV(islemler: [Islem], bundle: Bundle) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        numberFormatter.minimumFractionDigits = 2
        numberFormatter.maximumFractionDigits = 2
        numberFormatter.groupingSeparator = ""
        numberFormatter.decimalSeparator = "."
        
        // Headers
        var csv = "\(bundle.localizedString(forKey: "export.header.date", value: "Date", table: nil)),"
        csv += "\(bundle.localizedString(forKey: "export.header.name", value: "Name", table: nil)),"
        csv += "\(bundle.localizedString(forKey: "export.header.amount", value: "Amount", table: nil)),"
        csv += "\(bundle.localizedString(forKey: "export.header.type", value: "Type", table: nil)),"
        csv += "\(bundle.localizedString(forKey: "export.header.category", value: "Category", table: nil)),"
        csv += "\(bundle.localizedString(forKey: "export.header.account", value: "Account", table: nil))\n"
        
        // Data rows
        for islem in islemler {
            let tarih = dateFormatter.string(from: islem.tarih)
            let isim = escapeCSVString(islem.isim)
            let tutar = numberFormatter.string(from: NSNumber(value: islem.tutar)) ?? "0.00"
            let tur = bundle.localizedString(forKey: islem.tur.rawValue, value: islem.tur.rawValue, table: nil)
            
            let kategoriAdi = islem.kategori?.localizationKey ?? islem.kategori?.isim ?? "N/A"
            let kategori = escapeCSVString(bundle.localizedString(forKey: kategoriAdi, value: kategoriAdi, table: nil))
            
            let hesap = escapeCSVString(islem.hesap?.isim ?? "N/A")
            
            csv += "\(tarih),\(isim),\(tutar),\(tur),\(kategori),\(hesap)\n"
        }
        
        return csv
    }
    
    // 2. Taksitli İşlemler CSV
    private static func generateInstallmentsCSV(islemler: [Islem], bundle: Bundle) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        numberFormatter.minimumFractionDigits = 2
        numberFormatter.maximumFractionDigits = 2
        numberFormatter.groupingSeparator = ""
        numberFormatter.decimalSeparator = "."
        
        // Headers
        var csv = "\(bundle.localizedString(forKey: "export.installment.header.transaction_name", value: "", table: nil)),"
        csv += "\(bundle.localizedString(forKey: "export.installment.header.total_amount", value: "", table: nil)),"
        csv += "\(bundle.localizedString(forKey: "export.installment.header.installment_count", value: "", table: nil)),"
        csv += "\(bundle.localizedString(forKey: "export.installment.header.current_installment", value: "", table: nil)),"
        csv += "\(bundle.localizedString(forKey: "export.installment.header.installment_amount", value: "", table: nil)),"
        csv += "\(bundle.localizedString(forKey: "export.installment.header.date", value: "", table: nil)),"
        csv += "\(bundle.localizedString(forKey: "export.installment.header.category", value: "", table: nil)),"
        csv += "\(bundle.localizedString(forKey: "export.installment.header.account", value: "", table: nil))\n"
        
        // Data rows
        for islem in islemler {
            guard islem.taksitliMi else { continue }
            
            let baslikIsim = islem.isim.replacingOccurrences(
                of: " (\(islem.mevcutTaksitNo)/\(islem.toplamTaksitSayisi))",
                with: ""
            )
            
            let isim = escapeCSVString(baslikIsim)
            let toplamTutar = numberFormatter.string(from: NSNumber(value: islem.anaIslemTutari)) ?? "0.00"
            let taksitTutari = numberFormatter.string(from: NSNumber(value: islem.tutar)) ?? "0.00"
            let tarih = dateFormatter.string(from: islem.tarih)
            
            let kategoriAdi = islem.kategori?.localizationKey ?? islem.kategori?.isim ?? "N/A"
            let kategori = escapeCSVString(bundle.localizedString(forKey: kategoriAdi, value: kategoriAdi, table: nil))
            let hesap = escapeCSVString(islem.hesap?.isim ?? "N/A")
            
            csv += "\(isim),\(toplamTutar),\(islem.toplamTaksitSayisi),\(islem.mevcutTaksitNo),\(taksitTutari),\(tarih),\(kategori),\(hesap)\n"
        }
        
        return csv
    }
    
    // 3. Tekrarlı İşlemler CSV
    private static func generateRecurringCSV(islemler: [Islem], bundle: Bundle) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        numberFormatter.minimumFractionDigits = 2
        numberFormatter.maximumFractionDigits = 2
        numberFormatter.groupingSeparator = ""
        numberFormatter.decimalSeparator = "."
        
        // Tekrarlı işlemleri grupla
        var grupluIslemler: [UUID: [Islem]] = [:]
        for islem in islemler {
            if islem.tekrar != .tekSeferlik {
                grupluIslemler[islem.tekrarID, default: []].append(islem)
            }
        }
        
        // Headers
        var csv = "\(bundle.localizedString(forKey: "export.recurring.header.transaction_name", value: "", table: nil)),"
        csv += "\(bundle.localizedString(forKey: "export.recurring.header.amount", value: "", table: nil)),"
        csv += "\(bundle.localizedString(forKey: "export.recurring.header.start_date", value: "", table: nil)),"
        csv += "\(bundle.localizedString(forKey: "export.recurring.header.end_date", value: "", table: nil)),"
        csv += "\(bundle.localizedString(forKey: "export.recurring.header.frequency", value: "", table: nil)),"
        csv += "\(bundle.localizedString(forKey: "export.recurring.header.type", value: "", table: nil)),"
        csv += "\(bundle.localizedString(forKey: "export.recurring.header.category", value: "", table: nil)),"
        csv += "\(bundle.localizedString(forKey: "export.recurring.header.account", value: "", table: nil))\n"
        
        // Data rows
        for (_, grup) in grupluIslemler {
            guard let ilkIslem = grup.first else { continue }
            let baslangic = grup.min(by: { $0.tarih < $1.tarih })?.tarih ?? ilkIslem.tarih
            let bitis = ilkIslem.tekrarBitisTarihi
            
            let isim = escapeCSVString(ilkIslem.isim)
            let tutar = numberFormatter.string(from: NSNumber(value: ilkIslem.tutar)) ?? "0.00"
            let baslangicStr = dateFormatter.string(from: baslangic)
            let bitisStr = bitis != nil ? dateFormatter.string(from: bitis!) : "N/A"
            let sıklık = bundle.localizedString(forKey: ilkIslem.tekrar.rawValue, value: "", table: nil)
            let tur = bundle.localizedString(forKey: ilkIslem.tur.rawValue, value: "", table: nil)
            
            let kategoriAdi = ilkIslem.kategori?.localizationKey ?? ilkIslem.kategori?.isim ?? "N/A"
            let kategori = escapeCSVString(bundle.localizedString(forKey: kategoriAdi, value: kategoriAdi, table: nil))
            let hesap = escapeCSVString(ilkIslem.hesap?.isim ?? "N/A")
            
            csv += "\(isim),\(tutar),\(baslangicStr),\(bitisStr),\(sıklık),\(tur),\(kategori),\(hesap)\n"
        }
        
        return csv
    }
    
    // 4. Transferler CSV
    private static func generateTransfersCSV(transferler: [Transfer], bundle: Bundle) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        numberFormatter.minimumFractionDigits = 2
        numberFormatter.maximumFractionDigits = 2
        numberFormatter.groupingSeparator = ""
        numberFormatter.decimalSeparator = "."
        
        // Headers - description kaldırıldı
        var csv = "\(bundle.localizedString(forKey: "export.transfer.header.date", value: "", table: nil)),"
        csv += "\(bundle.localizedString(forKey: "export.transfer.header.amount", value: "", table: nil)),"
        csv += "\(bundle.localizedString(forKey: "export.transfer.header.from_account", value: "", table: nil)),"
        csv += "\(bundle.localizedString(forKey: "export.transfer.header.to_account", value: "", table: nil))\n"
        
        // Data rows - description kaldırıldı
        for transfer in transferler {
            let tarih = dateFormatter.string(from: transfer.tarih)
            let tutar = numberFormatter.string(from: NSNumber(value: transfer.tutar)) ?? "0.00"
            let kaynak = escapeCSVString(transfer.kaynakHesap?.isim ?? "N/A")
            let hedef = escapeCSVString(transfer.hedefHesap?.isim ?? "N/A")
            
            csv += "\(tarih),\(tutar),\(kaynak),\(hedef)\n"
        }
        
        return csv
    }
    
    // 5. Krediler CSV
    private static func generateLoansCSV(krediler: [Hesap], bundle: Bundle) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        numberFormatter.minimumFractionDigits = 2
        numberFormatter.maximumFractionDigits = 2
        numberFormatter.groupingSeparator = ""
        numberFormatter.decimalSeparator = "."
        
        // Headers
        var csv = "\(bundle.localizedString(forKey: "export.loan.header.account_name", value: "", table: nil)),"
        csv += "\(bundle.localizedString(forKey: "export.loan.header.loan_amount", value: "", table: nil)),"
        csv += "\(bundle.localizedString(forKey: "export.loan.header.interest_type", value: "", table: nil)),"
        csv += "\(bundle.localizedString(forKey: "export.loan.header.interest_rate", value: "", table: nil)),"
        csv += "\(bundle.localizedString(forKey: "export.loan.header.installment_count", value: "", table: nil)),"
        csv += "\(bundle.localizedString(forKey: "export.loan.header.installment_amount", value: "", table: nil)),"
        csv += "\(bundle.localizedString(forKey: "export.loan.header.first_payment_date", value: "", table: nil)),"
        csv += "\(bundle.localizedString(forKey: "export.loan.header.remaining_installments", value: "", table: nil)),"
        csv += "\(bundle.localizedString(forKey: "export.loan.header.remaining_amount", value: "", table: nil))\n"
        
        // Data rows
        for kredi in krediler {
            guard case let .kredi(cekilenTutar, faizTipi, faizOrani, taksitSayisi, ilkTaksitTarihi, taksitler) = kredi.detay else { continue }
            
            let odenmemisTaksitler = taksitler.filter { !$0.odendiMi }
            let kalanTaksitSayisi = odenmemisTaksitler.count
            let kalanTutar = odenmemisTaksitler.reduce(0) { $0 + $1.taksitTutari }
            let aylikTaksit = taksitler.first?.taksitTutari ?? 0
            
            let isim = escapeCSVString(kredi.isim)
            let krediTutari = numberFormatter.string(from: NSNumber(value: cekilenTutar)) ?? "0.00"
            let faizTipiStr = bundle.localizedString(forKey: faizTipi.localizedKey, value: "", table: nil)
            let taksitTutari = numberFormatter.string(from: NSNumber(value: aylikTaksit)) ?? "0.00"
            let ilkOdemeTarihi = dateFormatter.string(from: ilkTaksitTarihi)
            let kalanBorcStr = numberFormatter.string(from: NSNumber(value: kalanTutar)) ?? "0.00"
            
            csv += "\(isim),\(krediTutari),\(faizTipiStr),\(faizOrani),\(taksitSayisi),\(taksitTutari),\(ilkOdemeTarihi),\(kalanTaksitSayisi),\(kalanBorcStr)\n"
        }
        
        return csv
    }
    
    // 6. Kredi Taksitleri CSV
    private static func generateLoanInstallmentsCSV(krediler: [Hesap], bundle: Bundle) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        numberFormatter.minimumFractionDigits = 2
        numberFormatter.maximumFractionDigits = 2
        numberFormatter.groupingSeparator = ""
        numberFormatter.decimalSeparator = "."
        
        // Headers
        var csv = "\(bundle.localizedString(forKey: "export.loan_installments.header.loan_name", value: "", table: nil)),"
        csv += "\(bundle.localizedString(forKey: "export.loan_installments.header.installment_no", value: "", table: nil)),"
        csv += "\(bundle.localizedString(forKey: "export.loan_installments.header.amount", value: "", table: nil)),"
        csv += "\(bundle.localizedString(forKey: "export.loan_installments.header.due_date", value: "", table: nil)),"
        csv += "\(bundle.localizedString(forKey: "export.loan_installments.header.status", value: "", table: nil))\n"
        
        // Data rows
        for kredi in krediler {
            guard case let .kredi(_, _, _, _, _, taksitler) = kredi.detay else { continue }
            
            let krediAdi = escapeCSVString(kredi.isim)
            
            for (index, taksit) in taksitler.enumerated() {
                let tutar = numberFormatter.string(from: NSNumber(value: taksit.taksitTutari)) ?? "0.00"
                let vadeTarihi = dateFormatter.string(from: taksit.odemeTarihi)
                
                let durum = taksit.odendiMi ?
                    bundle.localizedString(forKey: "export.status.paid", value: "Paid", table: nil) :
                    bundle.localizedString(forKey: "export.status.pending", value: "Pending", table: nil)
                
                csv += "\(krediAdi),\(index + 1),\(tutar),\(vadeTarihi),\(durum)\n"
            }
        }
        
        return csv
    }
    
    // CSV escape helper
    private static func escapeCSVString(_ string: String) -> String {
        if string.contains(",") || string.contains("\"") || string.contains("\n") {
            let escapedString = string.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escapedString)\""
        }
        return string
    }
    
    // Eski tek CSV fonksiyonunu da koruyalım
    static func generateCSV(from islemler: [Islem], languageCode: String) -> String {
        // Mevcut implementasyon aynı kalacak
        guard let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
              let languageBundle = Bundle(path: path) else {
            return "Date,Name,Amount,Type,Category,Account\n"
        }
        
        return generateAllTransactionsCSV(islemler: islemler, bundle: languageBundle)
    }
}
