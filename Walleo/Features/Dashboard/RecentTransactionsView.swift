// Dosya: RecentTransactionsView.swift

import SwiftUI
import SwiftData

struct RecentTransactionsView: View {
    @EnvironmentObject var appSettings: AppSettings
    let modelContext: ModelContext
    let islemler: [Islem]
    let currentDate: Date

    @Binding var duzenlenecekIslem: Islem?
    let onSilmeyiBaslat: (Islem) -> Void
    
    // YENİ: Gösterilecek işlem sayısını sabit tut
    private let maxItemCount = 5
    
    var body: some View {
        if !islemler.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                // YENİ: Header'ı ayrı view'a çıkar
                headerView
                    .padding()
                
                Divider()
                
                // YENİ: İşlem listesini optimize et
                transactionListView
                    .padding([.horizontal, .bottom])
            }
            .background(Color(.systemGray6).opacity(0.4))
            .cornerRadius(12)
            .padding(.horizontal)
        } else {
            emptyStateView
        }
    }
    
    // YENİ: Header view
    @ViewBuilder
    private var headerView: some View {
        HStack {
            Text("dashboard.recent_transactions")
                .font(.headline)
                .fontWeight(.bold)
            
            Spacer()
            
            NavigationLink("dashboard.see_all") {
                TumIslemlerView(modelContext: modelContext, baslangicTarihi: currentDate)
                    .environmentObject(appSettings)
            }
        }
    }
    
    // YENİ: İşlem listesi
    @ViewBuilder
    private var transactionListView: some View {
        // YENİ: LazyVStack kullan
        LazyVStack(spacing: 0) {
            ForEach(Array(islemler.prefix(maxItemCount).enumerated()), id: \.element.id) { index, islem in
                // YENİ: Her satırı optimize et
                TransactionRowWrapper(
                    islem: islem,
                    onEdit: { duzenlenecekIslem = islem },
                    onDelete: { onSilmeyiBaslat(islem) }
                )
                
                if index < min(islemler.count, maxItemCount) - 1 {
                    Divider().padding(.leading, 60)
                }
            }
        }
    }
    
    // YENİ: Boş durum view'ı
    @ViewBuilder
    private var emptyStateView: some View {
        VStack {
            Spacer()
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 60))
            Text("dashboard.no_records_for_month")
                .font(.title3)
                .padding(.top)
            Spacer()
        }
        .padding(.top, 50)
    }
}

// YENİ: İşlem satırı wrapper - Gereksiz re-render'ları önler
struct TransactionRowWrapper: View {
    @EnvironmentObject var appSettings: AppSettings
    let islem: Islem
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        IslemSatirView(
            islem: islem,
            onEdit: onEdit,
            onDelete: onDelete
        )
        // YENİ: Satırları benzersiz id ile işaretle
        .id(islem.id)
    }
}
