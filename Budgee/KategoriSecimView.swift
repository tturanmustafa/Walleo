import SwiftUI
import SwiftData

struct KategoriSecimView: View {
    @Binding var secilenKategoriler: Set<UUID>
    @Query(sort: \Kategori.isim) private var tumKategoriler: [Kategori]
    @Environment(\.dismiss) private var dismiss
    
    // YENİ: Kategorileri Gelir ve Gider olarak ayırmak için
    private var gelirKategorileri: [Kategori] {
        tumKategoriler.filter { $0.tur == .gelir }
    }
    
    private var giderKategorileri: [Kategori] {
        tumKategoriler.filter { $0.tur == .gider }
    }
    
    var body: some View {
        NavigationStack {
            List {
                // DEĞİŞİKLİK: Başlık anahtarları düzeltildi.
                Section(header: Text(LocalizedStringKey("categories.expense_categories"))) {
                    ForEach(giderKategorileri) { kategori in
                        kategoriSatiri(kategori)
                    }
                }
                
                // DEĞİŞİKLİK: Başlık anahtarları düzeltildi.
                Section(header: Text(LocalizedStringKey("categories.income_categories"))) {
                    ForEach(gelirKategorileri) { kategori in
                        kategoriSatiri(kategori)
                    }
                }
            }
            .navigationTitle("common.categories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.reset") { secilenKategoriler.removeAll() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.done") { dismiss() }.fontWeight(.bold)
                }
            }
        }
    }
    
    @ViewBuilder
    private func kategoriSatiri(_ kategori: Kategori) -> some View {
        Button(action: {
            toggleKategori(kategori.id)
        }) {
            HStack {
                Image(systemName: secilenKategoriler.contains(kategori.id) ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(secilenKategoriler.contains(kategori.id) ? .blue : .secondary)
                
                Image(systemName: kategori.ikonAdi)
                    .frame(width: 24, height: 24)
                    .background(kategori.renk.opacity(0.2))
                    .foregroundColor(kategori.renk)
                    .cornerRadius(5)

                Text(LocalizedStringKey(kategori.localizationKey ?? kategori.isim))
                
                Spacer()
            }
        }
        .foregroundColor(.primary)
    }
    
    private func toggleKategori(_ id: UUID) {
        if secilenKategoriler.contains(id) {
            secilenKategoriler.remove(id)
        } else {
            secilenKategoriler.insert(id)
        }
    }
}
