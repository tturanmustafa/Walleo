import SwiftUI
import SwiftData

struct FiltreAyarView: View {
    @Binding var ayarlar: FiltreAyarlari
    @Environment(\.dismiss) var dismiss
    
    @Query(sort: \Kategori.isim) private var tumKategoriler: [Kategori]
    
    @State private var kategorilerAcik = true

    var body: some View {
        NavigationStack {
            Form {
                Section("Tarih Aralığı") {
                    Picker("Tarih Aralığı", selection: $ayarlar.tarihAraligi) {
                        ForEach(TarihAraligi.allCases) { aralik in Text(aralik.name).tag(aralik) }
                    }.pickerStyle(.menu)
                }
                Section("İşlem Türü") {
                    HStack(spacing: 10) {
                        Spacer()
                        FiltrePillView(text: "Tümü", isSelected: ayarlar.secilenTurler.count != 1) { ayarlar.secilenTurler = [.gelir, .gider] }
                        FiltrePillView(text: "Gelir", isSelected: ayarlar.secilenTurler == [.gelir]) { ayarlar.secilenTurler = [.gelir] }
                        FiltrePillView(text: "Gider", isSelected: ayarlar.secilenTurler == [.gider]) { ayarlar.secilenTurler = [.gider] }
                        Spacer()
                    }.padding(.vertical, 5)
                }
                Section {
                    DisclosureGroup("Kategoriler", isExpanded: $kategorilerAcik) {
                        WrappingHStack(items: tumKategoriler) { kategori in
                            FiltrePillView(text: kategori.isim, isSelected: ayarlar.secilenKategoriler.contains(kategori.id)) {
                                toggleKategori(kategori.id)
                            }
                        }.padding(.top, 8)
                    }
                }
                Section("Sırala") {
                    Picker("Sıralama Düzeni", selection: $ayarlar.sortOrder) {
                        ForEach(SortOrder.allCases) { order in Text(order.rawValue).tag(order) }
                    }.pickerStyle(.menu)
                }
            }
            .navigationTitle("Filtrele ve Sırala").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Sıfırla") { ayarlar = FiltreAyarlari() }.font(.body) }
                ToolbarItem(placement: .confirmationAction) { Button("Uygula") { dismiss() }.fontWeight(.bold) }
            }
        }
    }
    
    // Değişiklik burada. Artık doğrudan UUID alıyor.
    func toggleKategori(_ kategoriID: UUID) {
        if ayarlar.secilenKategoriler.contains(kategoriID) {
            ayarlar.secilenKategoriler.remove(kategoriID)
        } else {
            ayarlar.secilenKategoriler.insert(kategoriID)
        }
    }
}
