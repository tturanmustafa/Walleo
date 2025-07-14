//
//  KrediKartiRaporViewModel.swift
//  Walleo
//
//  Created by Mustafa Turan on 14.07.2025.
//


// KrediKartiRaporViewModel.swift
import SwiftUI
import SwiftData

@MainActor
class KrediKartiRaporViewModel: ObservableObject {
    @Published var creditCards: [Hesap] = []
    @Published var selectedCard: Hesap?
    @Published var totalSpent: Double = 0
    @Published var dailyAverage: Double = 0
    @Published var transactionCount: Int = 0
    @Published var largestPurchase: Double = 0
    @Published var dailySpending: [DailySpending] = []
    @Published var categoryBreakdown: [CategoryBreakdown] = []
    @Published var heatmapData: [[Double]] = Array(repeating: Array(repeating: 0, count: 24), count: 7)
    
    private let baslangicTarihi: Date
    private let bitisTarihi: Date
    private let modelContext: ModelContext
    
    init(baslangicTarihi: Date, bitisTarihi: Date, modelContext: ModelContext) {
        self.baslangicTarihi = baslangicTarihi
        self.bitisTarihi = bitisTarihi
        self.modelContext = modelContext
    }
    
    func loadData() async {
        await fetchCreditCards()
        if let firstCard = creditCards.first {
            selectCard(firstCard)
        }
    }
    
    private func fetchCreditCards() async {
        do {
            let descriptor = FetchDescriptor<Hesap>()
            let allAccounts = try modelContext.fetch(descriptor)
            creditCards = allAccounts.filter { hesap in
                if case .krediKarti = hesap.detay {
                    return true
                }
                return false
            }
        } catch {
            Logger.log("Error fetching credit cards: \(error)", log: Logger.data, type: .error)
        }
    }
    
    func selectCard(_ card: Hesap) {
        selectedCard = card
        Task {
            await calculateMetrics(for: card)
            await generateDailySpending(for: card)
            await calculateCategoryBreakdown(for: card)
            await generateHeatmap(for: card)
        }
    }
    
    private func calculateMetrics(for card: Hesap) async {
        do {
            let predicate = #Predicate<Islem> { islem in
                islem.hesap?.id == card.id &&
                islem.tarih >= baslangicTarihi &&
                islem.tarih <= bitisTarihi &&
                islem.turRawValue == IslemTuru.gider.rawValue
            }
            
            let descriptor = FetchDescriptor<Islem>(predicate: predicate)
            let transactions = try modelContext.fetch(descriptor)
            
            totalSpent = transactions.reduce(0) { $0 + $1.tutar }
            transactionCount = transactions.count
            largestPurchase = transactions.map { $0.tutar }.max() ?? 0
            
            let dayCount = Calendar.current.dateComponents([.day], from: baslangicTarihi, to: bitisTarihi).day ?? 1
            dailyAverage = totalSpent / Double(max(dayCount, 1))
            
        } catch {
            Logger.log("Error calculating metrics: \(error)", log: Logger.data, type: .error)
        }
    }
    
    private func generateDailySpending(for card: Hesap) async {
        do {
            let predicate = #Predicate<Islem> { islem in
                islem.hesap?.id == card.id &&
                islem.tarih >= baslangicTarihi &&
                islem.tarih <= bitisTarihi &&
                islem.turRawValue == IslemTuru.gider.rawValue
            }
            
            let descriptor = FetchDescriptor<Islem>(predicate: predicate, sortBy: [SortDescriptor(\.tarih)])
            let transactions = try modelContext.fetch(descriptor)
            
            var dailyData: [Date: Double] = [:]
            let calendar = Calendar.current
            
            for transaction in transactions {
                let startOfDay = calendar.startOfDay(for: transaction.tarih)
                dailyData[startOfDay, default: 0] += transaction.tutar
            }
            
            var currentDate = baslangicTarihi
            var spending: [DailySpending] = []
            
            while currentDate <= bitisTarihi {
                let startOfDay = calendar.startOfDay(for: currentDate)
                let amount = dailyData[startOfDay] ?? 0
                spending.append(DailySpending(date: startOfDay, amount: amount))
                currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
            }
            
            dailySpending = spending
            
        } catch {
            Logger.log("Error generating daily spending: \(error)", log: Logger.data, type: .error)
        }
    }
    
    private func calculateCategoryBreakdown(for card: Hesap) async {
        do {
            let predicate = #Predicate<Islem> { islem in
                islem.hesap?.id == card.id &&
                islem.tarih >= baslangicTarihi &&
                islem.tarih <= bitisTarihi &&
                islem.turRawValue == IslemTuru.gider.rawValue
            }
            
            let descriptor = FetchDescriptor<Islem>(predicate: predicate)
            let transactions = try modelContext.fetch(descriptor)
            
            var categoryData: [UUID: (kategori: Kategori, transactions: [Islem], total: Double)] = [:]
            
            for transaction in transactions {
                guard let kategori = transaction.kategori else { continue }
                
                if categoryData[kategori.id] == nil {
                    categoryData[kategori.id] = (kategori, [], 0)
                }
                
                categoryData[kategori.id]?.transactions.append(transaction)
                categoryData[kategori.id]?.total += transaction.tutar
            }
            
            categoryBreakdown = categoryData.values
                .sorted { $0.total > $1.total }
                .map { data in
                    CategoryBreakdown(
                        id: data.kategori.id,
                        name: data.kategori.localizationKey ?? data.kategori.isim,
                        icon: data.kategori.ikonAdi,
                        color: data.kategori.renk,
                        amount: data.total,
                        percentage: (data.total / totalSpent) * 100,
                        transactionCount: data.transactions.count,
                        transactions: data.transactions.sorted { $0.tarih > $1.tarih }
                    )
                }
            
        } catch {
            Logger.log("Error calculating category breakdown: \(error)", log: Logger.data, type: .error)
        }
    }
    
    private func generateHeatmap(for card: Hesap) async {
        do {
            let predicate = #Predicate<Islem> { islem in
                islem.hesap?.id == card.id &&
                islem.tarih >= baslangicTarihi &&
                islem.tarih <= bitisTarihi &&
                islem.turRawValue == IslemTuru.gider.rawValue
            }
            
            let descriptor = FetchDescriptor<Islem>(predicate: predicate)
            let transactions = try modelContext.fetch(descriptor)
            
            var heatmap = Array(repeating: Array(repeating: 0.0, count: 24), count: 7)
            let calendar = Calendar.current
            
            for transaction in transactions {
                let weekday = calendar.component(.weekday, from: transaction.tarih) - 1
                let hour = calendar.component(.hour, from: transaction.tarih)
                
                if weekday >= 0 && weekday < 7 && hour >= 0 && hour < 24 {
                    heatmap[weekday][hour] += transaction.tutar
                }
            }
            
            heatmapData = heatmap
            
        } catch {
            Logger.log("Error generating heatmap: \(error)", log: Logger.data, type: .error)
        }
    }
}

// Data Models
struct DailySpending: Identifiable {
    let id = UUID()
    let date: Date
    let amount: Double
}

struct CategoryBreakdown: Identifiable {
    let id: UUID
    let name: String
    let icon: String
    let color: Color
    let amount: Double
    let percentage: Double
    let transactionCount: Int
    let transactions: [Islem]
    
    var formattedAmount: String {
        formatCurrency(amount: amount, currencyCode: "TRY", localeIdentifier: "tr")
    }
}