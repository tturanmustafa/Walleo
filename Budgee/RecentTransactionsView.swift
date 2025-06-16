import SwiftUI
import SwiftData // EKSİK OLAN VE HATAYI ÇÖZECEK OLAN SATIR

struct RecentTransactionsView: View {
    let modelContext: ModelContext
    let islemler: [Islem]
    
    @Binding var duzenlenecekIslem: Islem?
    @Binding var duzenlemeEkraniGosteriliyor: Bool
    let onSilmeyiBaslat: (Islem) -> Void
    
    var body: some View {
        if !islemler.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("dashboard.recent_transactions").font(.headline).fontWeight(.bold)
                    Spacer()
                    NavigationLink("dashboard.see_all") {
                        TumIslemlerView(modelContext: modelContext)
                    }
                }.padding()
                Divider()
                VStack(spacing: 0) {
                    ForEach(islemler.prefix(5)) { islem in
                        IslemSatirView(
                            islem: islem,
                            onEdit: {
                                duzenlenecekIslem = islem
                                duzenlemeEkraniGosteriliyor = true
                            },
                            onDelete: {
                                onSilmeyiBaslat(islem)
                            }
                        )
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                onSilmeyiBaslat(islem)
                            } label: { Label("common.delete", systemImage: "trash") }
                            
                            Button {
                                duzenlenecekIslem = islem
                                duzenlemeEkraniGosteriliyor = true
                            } label: { Label("common.edit", systemImage: "pencil") }
                            .tint(.blue)
                        }
                        
                        if islem.id != islemler.prefix(5).last?.id { Divider().padding(.leading, 60) }
                    }
                }
                .padding([.horizontal, .bottom])
            }
            .background(Color(.systemGray6).opacity(0.4))
            .cornerRadius(12)
            .padding(.horizontal)
        } else {
            VStack {
                Spacer()
                Image(systemName: "doc.text.magnifyingglass").font(.system(size: 60))
                Text("dashboard.no_records_for_month").font(.title3).padding(.top)
                Spacer()
            }
            .padding(.top, 50)
        }
    }
}
