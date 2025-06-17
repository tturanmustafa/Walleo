import SwiftUI
import SwiftData

struct RecentTransactionsView: View {
    @EnvironmentObject var appSettings: AppSettings // YENİ: Ayar panosuna erişim
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
                            .environmentObject(appSettings) // Ayarları bir sonraki ekrana da aktarıyoruz
                    }
                }.padding()
                Divider()
                VStack(spacing: 0) {
                    ForEach(islemler.prefix(5)) { islem in
                        // IslemSatirView artık ortamdan appSettings'i kendi bulacak
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
