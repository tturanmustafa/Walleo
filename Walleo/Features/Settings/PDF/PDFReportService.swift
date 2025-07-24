// PDFReportService.swift
import Foundation
import PDFKit
import SwiftUI
import SwiftData
import Charts
import UIKit

@MainActor
class PDFReportService {
    private let modelContext: ModelContext
    private let languageCode: String
    private let currencyCode: String
    private let dateFormatter: DateFormatter
    private let currencyFormatter: NumberFormatter
    
    init(modelContext: ModelContext, languageCode: String, currencyCode: String) {
        self.modelContext = modelContext
        self.languageCode = languageCode
        self.currencyCode = currencyCode
        
        // Date formatter
        self.dateFormatter = DateFormatter()
        self.dateFormatter.locale = Locale(identifier: languageCode)
        self.dateFormatter.dateStyle = .medium
        
        // Currency formatter
        self.currencyFormatter = NumberFormatter()
        self.currencyFormatter.numberStyle = .currency
        self.currencyFormatter.locale = Locale(identifier: languageCode)
        self.currencyFormatter.currencyCode = currencyCode
    }
    
    func generateDetailedPDFReport(startDate: Date, endDate: Date) async -> URL? {
        // Language bundle
        guard let languageBundle = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
              let bundle = Bundle(path: languageBundle) else { return nil }
        
        // Önce tüm verileri topla
        let reportData = await collectReportData(startDate: startDate, endDate: endDate)
        
        // Sonra PDF oluştur (synchronous)
        return createPDF(with: reportData, startDate: startDate, endDate: endDate, bundle: bundle)
    }
    
    // MARK: - Data Collection
    private func collectReportData(startDate: Date, endDate: Date) async -> ReportData {
        var reportData = ReportData()
        
        // Kredi Kartı Verileri
        let creditCardViewModel = KrediKartiRaporuViewModel(
            modelContext: modelContext,
            baslangicTarihi: startDate,
            bitisTarihi: endDate
        )
        await creditCardViewModel.fetchData()
        reportData.creditCardSummary = creditCardViewModel.genelOzet
        reportData.creditCardDetails = creditCardViewModel.kartDetayRaporlari
        
        // Kredi Verileri
        let loanViewModel = KrediRaporuViewModel(
            modelContext: modelContext,
            baslangicTarihi: startDate,
            bitisTarihi: endDate
        )
        await loanViewModel.fetchData()
        reportData.loanSummary = loanViewModel.genelOzet
        reportData.loanDetails = loanViewModel.krediDetayRaporlari
        
        // Grafik görüntülerini oluştur
        for (index, detail) in reportData.creditCardDetails.enumerated() {
            if !detail.kategoriDagilimi.isEmpty {
                reportData.creditCardChartImages[detail.id] = await createDonutChartImage(
                    data: detail.kategoriDagilimi,
                    size: CGSize(width: 300, height: 200)
                )
            }
        }
        
        return reportData
    }
    
    // MARK: - PDF Creation (Synchronous)
    private func createPDF(with reportData: ReportData, startDate: Date, endDate: Date, bundle: Bundle) -> URL? {
        let pageWidth: CGFloat = 595 // A4 width
        let pageHeight: CGFloat = 842 // A4 height
        let margin: CGFloat = 40
        
        // PDF Renderer
        let format = UIGraphicsPDFRendererFormat()
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        
        // Generate PDF data
        let data = renderer.pdfData { context in
            // Title page
            context.beginPage()
            drawTitlePage(
                in: context.cgContext,
                pageRect: pageRect,
                startDate: startDate,
                endDate: endDate,
                bundle: bundle
            )
            
            // Credit Card Report
            if !reportData.creditCardDetails.isEmpty {
                // Summary page
                context.beginPage()
                drawCreditCardSummary(
                    in: context.cgContext,
                    pageRect: pageRect,
                    margin: margin,
                    ozet: reportData.creditCardSummary,
                    bundle: bundle
                )
                
                // Detail pages
                for detail in reportData.creditCardDetails {
                    context.beginPage()
                    drawCreditCardDetail(
                        in: context.cgContext,
                        pageRect: pageRect,
                        margin: margin,
                        rapor: detail,
                        chartImage: reportData.creditCardChartImages[detail.id],
                        bundle: bundle
                    )
                }
            }
            
            // Loan Report
            if !reportData.loanDetails.isEmpty {
                // Summary page
                context.beginPage()
                drawLoanSummary(
                    in: context.cgContext,
                    pageRect: pageRect,
                    margin: margin,
                    ozet: reportData.loanSummary,
                    bundle: bundle
                )
                
                // Detail pages
                for detail in reportData.loanDetails {
                    context.beginPage()
                    drawLoanDetail(
                        in: context.cgContext,
                        pageRect: pageRect,
                        margin: margin,
                        rapor: detail,
                        bundle: bundle
                    )
                }
            }
        }
        
        // Save to file
        let fileName = "Walleo_Report_\(dateFormatter.string(from: startDate))_\(dateFormatter.string(from: endDate)).pdf"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try data.write(to: tempURL)
            return tempURL
        } catch {
            Logger.log("PDF dosyası yazılamadı: \(error)", log: Logger.service, type: .error)
            return nil
        }
    }
    
    // MARK: - Title Page
    private func drawTitlePage(
        in context: CGContext,
        pageRect: CGRect,
        startDate: Date,
        endDate: Date,
        bundle: Bundle
    ) {
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 36, weight: .bold),
            .foregroundColor: UIColor.black
        ]
        
        let title = bundle.localizedString(forKey: "pdf.report.main_title", value: "Financial Report", table: nil)
        let titleSize = title.size(withAttributes: titleAttributes)
        let titleRect = CGRect(
            x: (pageRect.width - titleSize.width) / 2,
            y: 200,
            width: titleSize.width,
            height: titleSize.height
        )
        title.draw(in: titleRect, withAttributes: titleAttributes)
        
        // Date Range
        let dateRangeText = "\(dateFormatter.string(from: startDate)) - \(dateFormatter.string(from: endDate))"
        let dateAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 18),
            .foregroundColor: UIColor.darkGray
        ]
        let dateSize = dateRangeText.size(withAttributes: dateAttributes)
        let dateRect = CGRect(
            x: (pageRect.width - dateSize.width) / 2,
            y: titleRect.maxY + 20,
            width: dateSize.width,
            height: dateSize.height
        )
        dateRangeText.draw(in: dateRect, withAttributes: dateAttributes)
        
        // Generated date
        let generatedText = bundle.localizedString(forKey: "pdf.report.generated_on", value: "Generated on", table: nil) + " " + dateFormatter.string(from: Date())
        let generatedAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor.lightGray
        ]
        let generatedSize = generatedText.size(withAttributes: generatedAttributes)
        let generatedRect = CGRect(
            x: (pageRect.width - generatedSize.width) / 2,
            y: pageRect.height - 100,
            width: generatedSize.width,
            height: generatedSize.height
        )
        generatedText.draw(in: generatedRect, withAttributes: generatedAttributes)
    }
    
    // MARK: - Credit Card Summary
    private func drawCreditCardSummary(
        in context: CGContext,
        pageRect: CGRect,
        margin: CGFloat,
        ozet: KrediKartiGenelOzet,
        bundle: Bundle
    ) {
        var yPosition: CGFloat = margin
        
        // Başlık
        let titleText = bundle.localizedString(forKey: "reports.creditcard.summary", value: "Credit Card Summary", table: nil)
        yPosition = drawText(titleText, at: CGPoint(x: margin, y: yPosition), width: pageRect.width - 2 * margin, fontSize: 24, weight: .bold)
        yPosition += 20
        
        // Genel metrikler
        let metrics = [
            (bundle.localizedString(forKey: "reports.creditcard.total_spending", value: "", table: nil), currencyFormatter.string(from: NSNumber(value: ozet.toplamHarcama)) ?? ""),
            (bundle.localizedString(forKey: "reports.creditcard.active_cards", value: "", table: nil), "\(ozet.aktifKartSayisi)"),
            (bundle.localizedString(forKey: "reports.creditcard.transactions", value: "", table: nil), "\(ozet.islemSayisi)"),
            (bundle.localizedString(forKey: "reports.creditcard.daily_avg", value: "", table: nil), currencyFormatter.string(from: NSNumber(value: ozet.gunlukOrtalama)) ?? "")
        ]
        
        for metric in metrics {
            yPosition = drawMetric(metric.0, value: metric.1, at: CGPoint(x: margin, y: yPosition), width: pageRect.width - 2 * margin)
            yPosition += 15
        }
    }
    
    // MARK: - Credit Card Detail
    private func drawCreditCardDetail(
        in context: CGContext,
        pageRect: CGRect,
        margin: CGFloat,
        rapor: KartDetayRaporu,
        chartImage: UIImage?,
        bundle: Bundle
    ) {
        var yPosition: CGFloat = margin
        
        // Kart adı
        yPosition = drawText(rapor.hesap.isim, at: CGPoint(x: margin, y: yPosition), width: pageRect.width - 2 * margin, fontSize: 20, weight: .bold)
        yPosition += 20
        
        // Kart metrikleri
        var cardMetrics = [
            (bundle.localizedString(forKey: "reports.creditcard.spending", value: "", table: nil), currencyFormatter.string(from: NSNumber(value: rapor.toplamHarcama)) ?? ""),
            (bundle.localizedString(forKey: "reports.creditcard.transactions", value: "", table: nil), "\(rapor.islemSayisi ?? 0)")
        ]
        
        if let limit = rapor.kartLimiti {
            cardMetrics.append((bundle.localizedString(forKey: "reports.creditcard.limit", value: "", table: nil), currencyFormatter.string(from: NSNumber(value: limit)) ?? ""))
        }
        
        if let doluluk = rapor.kartDolulukOrani {
            cardMetrics.append((bundle.localizedString(forKey: "reports.creditcard.usage", value: "", table: nil), String(format: "%.0f%%", doluluk)))
        }
        
        for metric in cardMetrics {
            yPosition = drawMetric(metric.0, value: metric.1, at: CGPoint(x: margin, y: yPosition), width: pageRect.width - 2 * margin)
            yPosition += 12
        }
        
        yPosition += 20
        
        // Kategori dağılımı grafiği
        if !rapor.kategoriDagilimi.isEmpty {
            let chartTitle = bundle.localizedString(forKey: "reports.creditcard.category_distribution", value: "", table: nil)
            yPosition = drawText(chartTitle, at: CGPoint(x: margin, y: yPosition), width: pageRect.width - 2 * margin, fontSize: 16, weight: .semibold)
            yPosition += 10
            
            // Donut chart görüntüsü
            if let chartImage = chartImage {
                let chartRect = CGRect(x: (pageRect.width - 300) / 2, y: yPosition, width: 300, height: 200)
                chartImage.draw(in: chartRect)
                yPosition = chartRect.maxY + 20
            }
            
            // Kategori listesi
            for kategori in rapor.kategoriDagilimi.prefix(5) {
                let categoryName = bundle.localizedString(forKey: kategori.localizationKey ?? kategori.kategori, value: kategori.kategori, table: nil)
                let categoryText = "• \(categoryName): \(currencyFormatter.string(from: NSNumber(value: kategori.tutar)) ?? "")"
                yPosition = drawText(categoryText, at: CGPoint(x: margin + 20, y: yPosition), width: pageRect.width - 2 * margin - 40, fontSize: 12)
                yPosition += 12
            }
        }
    }
    
    // MARK: - Loan Summary
    private func drawLoanSummary(
        in context: CGContext,
        pageRect: CGRect,
        margin: CGFloat,
        ozet: KrediGenelOzet,
        bundle: Bundle
    ) {
        var yPosition: CGFloat = margin
        
        // Başlık
        let titleText = bundle.localizedString(forKey: "loan_report.summary", value: "Loan Summary", table: nil)
        yPosition = drawText(titleText, at: CGPoint(x: margin, y: yPosition), width: pageRect.width - 2 * margin, fontSize: 24, weight: .bold)
        yPosition += 20
        
        // Genel metrikler
        let metrics = [
            (bundle.localizedString(forKey: "loan_report.active_loans", value: "", table: nil), "\(ozet.aktifKrediSayisi)"),
            (bundle.localizedString(forKey: "loan_report.total_remaining", value: "", table: nil), currencyFormatter.string(from: NSNumber(value: ozet.toplamKalanBorc)) ?? ""),
            (bundle.localizedString(forKey: "loan_report.monthly_payment", value: "", table: nil), currencyFormatter.string(from: NSNumber(value: ozet.aylikToplamTaksitYuku)) ?? ""),
            (bundle.localizedString(forKey: "loan_report.progress", value: "", table: nil), String(format: "%.1f%%", ozet.ilerlemeYuzdesi))
        ]
        
        for metric in metrics {
            yPosition = drawMetric(metric.0, value: metric.1, at: CGPoint(x: margin, y: yPosition), width: pageRect.width - 2 * margin)
            yPosition += 15
        }
    }
    
    // MARK: - Loan Detail
    private func drawLoanDetail(
        in context: CGContext,
        pageRect: CGRect,
        margin: CGFloat,
        rapor: KrediDetayRaporu,
        bundle: Bundle
    ) {
        var yPosition: CGFloat = margin
        
        // Kredi adı
        yPosition = drawText(rapor.hesap.isim, at: CGPoint(x: margin, y: yPosition), width: pageRect.width - 2 * margin, fontSize: 20, weight: .bold)
        yPosition += 20
        
        // Kredi detayları
        if let detay = rapor.krediDetaylari {
            let loanMetrics = [
                (bundle.localizedString(forKey: "loan_report.principal_amount", value: "", table: nil), currencyFormatter.string(from: NSNumber(value: detay.cekilenTutar)) ?? ""),
                (bundle.localizedString(forKey: "loan_report.interest_rate", value: "", table: nil), String(format: "%.2f%%", detay.faizOrani)),
                (bundle.localizedString(forKey: "loan_report.remaining", value: "", table: nil), currencyFormatter.string(from: NSNumber(value: detay.kalanAnaparaTutari)) ?? ""),
                (bundle.localizedString(forKey: "loan_report.progress", value: "", table: nil), String(format: "%.0f%%", rapor.ilerlemeYuzdesi))
            ]
            
            for metric in loanMetrics {
                yPosition = drawMetric(metric.0, value: metric.1, at: CGPoint(x: margin, y: yPosition), width: pageRect.width - 2 * margin)
                yPosition += 12
            }
        }
        
        yPosition += 20
        
        // Performans
        let performanceTitle = bundle.localizedString(forKey: "loan_report.payment_performance", value: "", table: nil)
        yPosition = drawText(performanceTitle, at: CGPoint(x: margin, y: yPosition), width: pageRect.width - 2 * margin, fontSize: 16, weight: .semibold)
        yPosition += 10
        
        let performanceMetrics = [
            (bundle.localizedString(forKey: "loan_report.on_time", value: "", table: nil), "\(rapor.odemePerformansi.zamanindaOdenenSayisi)"),
            (bundle.localizedString(forKey: "loan_report.late", value: "", table: nil), "\(rapor.odemePerformansi.gecOdenenSayisi)"),
            (bundle.localizedString(forKey: "loan_report.score", value: "", table: nil), String(format: "%.0f%%", rapor.odemePerformansi.performansSkoru))
        ]
        
        for metric in performanceMetrics {
            yPosition = drawText("• \(metric.0): \(metric.1)", at: CGPoint(x: margin + 20, y: yPosition), width: pageRect.width - 2 * margin - 40, fontSize: 12)
            yPosition += 12
        }
    }
    
    // MARK: - Helper Methods
    private func drawText(_ text: String, at point: CGPoint, width: CGFloat, fontSize: CGFloat, weight: UIFont.Weight = .regular) -> CGFloat {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize, weight: weight),
            .foregroundColor: UIColor.black
        ]
        
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let textRect = CGRect(x: point.x, y: point.y, width: width, height: CGFloat.greatestFiniteMagnitude)
        let boundingRect = attributedString.boundingRect(with: textRect.size, options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
        
        attributedString.draw(in: CGRect(x: point.x, y: point.y, width: width, height: boundingRect.height))
        
        return point.y + boundingRect.height
    }
    
    private func drawMetric(_ label: String, value: String, at point: CGPoint, width: CGFloat) -> CGFloat {
        let labelAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14),
            .foregroundColor: UIColor.darkGray
        ]
        
        let valueAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14, weight: .semibold),
            .foregroundColor: UIColor.black
        ]
        
        let labelWidth = width * 0.6
        let valueWidth = width * 0.4
        
        let labelString = NSAttributedString(string: label, attributes: labelAttributes)
        let valueString = NSAttributedString(string: value, attributes: valueAttributes)
        
        labelString.draw(in: CGRect(x: point.x, y: point.y, width: labelWidth, height: 20))
        valueString.draw(in: CGRect(x: point.x + labelWidth, y: point.y, width: valueWidth, height: 20))
        
        return point.y + 20
    }
    
    // MARK: - Chart Image Creation
    @MainActor
    private func createDonutChartImage(data: [KategoriHarcamasi], size: CGSize) async -> UIImage? {
        let hostingController = UIHostingController(
            rootView: DonutChartView(data: data)
                .frame(width: size.width, height: size.height)
                .background(Color.white)
        )
        
        hostingController.view.bounds = CGRect(origin: .zero, size: size)
        hostingController.view.backgroundColor = .white
        hostingController.view.isOpaque = true
        
        // View'in layout'unu zorla
        hostingController.view.setNeedsLayout()
        hostingController.view.layoutIfNeeded()
        
        let renderer = UIGraphicsImageRenderer(size: size, format: UIGraphicsImageRendererFormat.default())
        return renderer.image { context in
            hostingController.view.layer.render(in: context.cgContext)
        }
    }
}

// MARK: - Report Data Structure
private struct ReportData {
    var creditCardSummary = KrediKartiGenelOzet()
    var creditCardDetails: [KartDetayRaporu] = []
    var creditCardChartImages: [UUID: UIImage] = [:]
    var loanSummary = KrediGenelOzet()
    var loanDetails: [KrediDetayRaporu] = []
}
