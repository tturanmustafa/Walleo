// Dosya: RecentTransactionsView.swift

import SwiftUI
import SwiftData

struct RecentTransactionsView: View {
    @EnvironmentObject var appSettings: AppSettings
    let modelContext: ModelContext
    let islemler: [Islem]
    
    // GÜNCELLEME: 'currentDate' parametresi kaldırıldı.
    
    @Binding var duzenlenecekIslem: Islem?
    let onSilmeyiBaslat: (Islem) -> Void
    
    var body: some View {
        if !islemler.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("dashboard.recent_transactions").font(.headline).fontWeight(.bold)
                    Spacer()
                    // GÜNCELLEME: NavigationLink orijinal, basit haline geri döndü.
                    NavigationLink("dashboard.see_all") {
                        TumIslemlerView(modelContext: modelContext)
                            .environmentObject(appSettings)
                    }
                }.padding()
                
                Divider()
                
                VStack(spacing: 0) {
                    ForEach(islemler.prefix(5)) { islem in
                        IslemSatirView(
                            islem: islem,
                            onEdit: {
                                duzenlenecekIslem = islem
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
