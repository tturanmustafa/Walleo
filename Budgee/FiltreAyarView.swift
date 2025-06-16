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
                tarihAraligiSection
                islemTuruSection
                kategorilerSection
                siralamaSection
            }
            .navigationTitle("filter.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("common.reset") { ayarlar = FiltreAyarlari() }.font(.body) }
                ToolbarItem(placement: .confirmationAction) { Button("common.apply") { dismiss() }.fontWeight(.bold) }
            }
        }
    }
    
    private var tarihAraligiSection: some View {
        Section("filter.date_range") {
            Picker("filter.date_range", selection: $ayarlar.tarihAraligi) {
                ForEach(TarihAraligi.allCases) { aralik in
                    Text(aralik.localized).tag(aralik)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
        }
    }
    
    private var islemTuruSection: some View {
        Section("transaction.type") {
            HStack(spacing: 10) {
                Spacer()
                FiltrePillView(text: String(localized: "common.all"), isSelected: ayarlar.secilenTurler.count != 1) { ayarlar.secilenTurler = [.gelir, .gider] }
                FiltrePillView(text: String(localized: "common.income"), isSelected: ayarlar.secilenTurler == [.gelir]) { ayarlar.secilenTurler = [.gelir] }
                FiltrePillView(text: String(localized: "common.expense"), isSelected: ayarlar.secilenTurler == [.gider]) { ayarlar.secilenTurler = [.gider] }
                Spacer()
            }
            .padding(.vertical, 5)
        }
    }
    
    private var kategorilerSection: some View {
        Section {
            DisclosureGroup("common.categories", isExpanded: $kategorilerAcik) {
                WrappingHStack(items: tumKategoriler) { kategori in
                    // DEĞİŞİKLİK: FiltrePillView'e metni vermeden önce çeviriyoruz.
                    FiltrePillView(text: NSLocalizedString(kategori.localizationKey ?? kategori.isim, comment: ""),
                                    isSelected: ayarlar.secilenKategoriler.contains(kategori.id)) {
                        toggleKategori(kategori.id)
                    }
                }
                .padding(.top, 8)
            }
        }
    }
    
    private var siralamaSection: some View {
        Section("filter.sort_by") {
            Picker("filter.sort_order", selection: $ayarlar.sortOrder) {
                ForEach(SortOrder.allCases) { order in
                    Text(order.localized).tag(order)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
        }
    }
    
    private func toggleKategori(_ kategoriID: UUID) {
        if ayarlar.secilenKategoriler.contains(kategoriID) {
            ayarlar.secilenKategoriler.remove(kategoriID)
        } else {
            ayarlar.secilenKategoriler.insert(kategoriID)
        }
    }
}
