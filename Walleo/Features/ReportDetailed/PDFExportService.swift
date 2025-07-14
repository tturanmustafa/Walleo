//
//  PDFExportService.swift
//  Walleo
//
//  Created by Mustafa Turan on 14.07.2025.
//


// Dosya: PDFExportService.swift

import Foundation
import PDFKit
import SwiftUI

@MainActor
class PDFExportService {
    
    static func generateDetailedReportsPDF(
        reports: [DetayliRaporlarView.RaporTuru],
        dateRange: (start: Date, end: Date),
        viewModel: DetayliRaporlarViewModel,
        languageCode: String,
        currencyCode: String
    ) async throws -> URL {
        
        let pdfMetaData = [
            kCGPDFContextCreator: "Walleo",
            kCGPDFContextAuthor: "Walleo User",
            kCGPDFContextTitle: getLocalizedString("pdf.detailed_reports.title", languageCode: languageCode)
        ]
        
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]
        
        let pageWidth = 8.5 * 72.0
        let pageHeight = 11 * 72.0
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        
        let data = renderer.pdfData { context in
            context.beginPage()
            
            var yPosition: CGFloat = 50
            
            // Başlık
            let titleText = getLocalizedString("pdf.detailed_reports.title", languageCode: languageCode)
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 24),
                .foregroundColor: UIColor.label
            ]
            titleText.draw(at: CGPoint(x: 50, y: yPosition), withAttributes: titleAttributes)
            yPosition += 40
            
            // Tarih aralığı
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: languageCode)
            dateFormatter.dateStyle = .medium
            
            let dateRangeText = "\(dateFormatter.string(from: dateRange.start)) - \(dateFormatter.string(from: dateRange.end))"
            let dateAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14),
                .foregroundColor: UIColor.secondaryLabel
            ]
            dateRangeText.draw(at: CGPoint(x: 50, y: yPosition), withAttributes: dateAttributes)
            yPosition += 30
            
            // Çizgi
            UIColor.separator.setFill()
            context.fill(CGRect(x: 50, y: yPosition, width: pageWidth - 100, height: 1))
            yPosition += 20
            
            // Raporlar
            for report in reports {
                // Yeni sayfa kontrolü
                if yPosition > pageHeight - 100 {
                    context.beginPage()
                    yPosition = 50
                }
                
                // Rapor başlığı
                let reportTitle = getLocalizedString(report.baslik, languageCode: languageCode)
                let reportTitleAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.boldSystemFont(ofSize: 18),
                    .foregroundColor: UIColor.label
                ]
                reportTitle.draw(at: CGPoint(x: 50, y: yPosition), withAttributes: reportTitleAttributes)
                yPosition += 30
                
                // Rapor içeriği (her rapor türüne göre özelleştirilmiş)
                yPosition = await drawReportContent(
                    report: report,
                    context: context,
                    yPosition: yPosition,
                    pageWidth: pageWidth,
                    viewModel: viewModel,
                    languageCode: languageCode,
                    currencyCode: currencyCode
                )
                
                yPosition += 30
            }
            
            // Footer
            let footerText = "Walleo - \(DateFormatter.localizedString(from: Date(), dateStyle: .long, timeStyle: .none))"
            let footerAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10),
                .foregroundColor: UIColor.tertiaryLabel
            ]
            let footerSize = footerText.size(withAttributes: footerAttributes)
            footerText.draw(
                at: CGPoint(x: (pageWidth - footerSize.width) / 2, y: pageHeight - 30),
                withAttributes: footerAttributes
            )
        }
        
        // PDF'i geçici dizine kaydet
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("Walleo_DetailedReports_\(Date().timeIntervalSince1970).pdf")
        try data.write(to: tempURL)
        
        return tempURL
    }
    
    private static func drawReportContent(
        report: DetayliRaporlarView.RaporTuru,
        context: UIGraphicsPDFRendererContext,
        yPosition: CGFloat,
        pageWidth: CGFloat,
        viewModel: DetayliRaporlarViewModel,
        languageCode: String,
        currencyCode: String
    ) async -> CGFloat {
        
        var currentY = yPosition
        let contentAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor.label
        ]
        
        switch report {
        case .nakitAkisi:
            if let data = viewModel.nakitAkisiVerisi {
                // Özet kartları
                let toplamGelir = data.reduce(0) { $0 + $1.gelir }
                let toplamGider = data.reduce(0) { $0 + $1.gider }
                let netFark = toplamGelir - toplamGider
                
                let summaryText = """
                \(getLocalizedString("common.income", languageCode: languageCode)): \(formatCurrency(amount: toplamGelir, currencyCode: currencyCode, localeIdentifier: languageCode))
                \(getLocalizedString("common.expense", languageCode: languageCode)): \(formatCurrency(amount: toplamGider, currencyCode: currencyCode, localeIdentifier: languageCode))
                \(getLocalizedString("reports.summary.net_flow", languageCode: languageCode)): \(formatCurrency(amount: netFark, currencyCode: currencyCode, localeIdentifier: languageCode))
                """
                
                summaryText.draw(
                    in: CGRect(x: 70, y: currentY, width: pageWidth - 140, height: 100),
                    withAttributes: contentAttributes
                )
                currentY += 80
            }
            
        case .kategoriRadari:
            if let gelirData = viewModel.kategoriGelirVerisi,
               let giderData = viewModel.kategoriGiderVerisi {
                // En yüksek 5 kategoriyi listele
                let topGiderler = giderData.sorted { $0.toplamTutar > $1.toplamTutar }.prefix(5)
                
                var categoryText = getLocalizedString("categories.expense_categories", languageCode: languageCode) + ":\n"
                for item in topGiderler {
                    categoryText += "• \(item.kategori.isim): \(formatCurrency(amount: item.toplamTutar, currencyCode: currencyCode, localeIdentifier: languageCode)) (\(String(format: "%.1f%%", item.yuzde)))\n"
                }
                
                categoryText.draw(
                    in: CGRect(x: 70, y: currentY, width: pageWidth - 140, height: 150),
                    withAttributes: contentAttributes
                )
                currentY += 120
            }
            
        // Diğer rapor türleri için benzer implementasyonlar...
        default:
            let placeholderText = getLocalizedString("pdf.content_not_available", languageCode: languageCode)
            placeholderText.draw(at: CGPoint(x: 70, y: currentY), withAttributes: contentAttributes)
            currentY += 30
        }
        
        return currentY
    }
    
    private static func getLocalizedString(_ key: String, languageCode: String) -> String {
        guard let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return key
        }
        return bundle.localizedString(forKey: key, value: key, table: nil)
    }
}