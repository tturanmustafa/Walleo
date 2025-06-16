import SwiftUI
import SwiftData

struct RecentTransactionsView: View {
    let modelContext: ModelContext // Üstten gelen context
    let islemler: [Islem]
    
    // Düzenleme ve silme aksiyonlarını tetiklemek için Binding'ler ve closure'lar
    @Binding var duzenlenecekIslem: Islem?
    @Binding var duzenlemeEkraniGosteriliyor: Bool
    let onSilmeyiBaslat: (Islem) -> Void
    
    var body: some View {
        if !islemler.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Son İşlemler").font(.headline).fontWeight(.bold)
                    Spacer()
                    // DEĞİŞİKLİK BURADA: NavigationLink'in içeriği güncellendi.
                    NavigationLink("Tümü") {
                        // TumIslemlerView'i yaratırken ona hazır bir ViewModel veriyoruz.
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
                            } label: { Label("Sil", systemImage: "trash") }
                            
                            Button {
                                duzenlenecekIslem = islem
                                duzenlemeEkraniGosteriliyor = true
                            } label: { Label("Düzenle", systemImage: "pencil") }
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
                Text("Bu Ay İçin Kayıt Yok").font(.title3).padding(.top)
                Spacer()
            }
            .padding(.top, 50)
        }
    }
}
