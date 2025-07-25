import SwiftUI
import SwiftData

struct KategoriYonetimView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appSettings: AppSettings
    @Query(sort: \Kategori.isim) private var kategoriler: [Kategori]
    @State private var yeniKategoriEkleGoster = false
    @State private var silinecekKategori: Kategori?
    @State private var sistemKategoriUyarisi = false  // YENİ EKLE

    private var gelirKategorileri: [Kategori] {
        kategoriler.filter { $0.tur == .gelir }
    }
    private var giderKategorileri: [Kategori] {
        kategoriler.filter { $0.tur == .gider }
    }

    var body: some View {
        List {
            Section(LocalizedStringKey("categories.income_categories")) {
                ForEach(gelirKategorileri) { kategori in
                    kategoriSatiri(kategori: kategori)
                        .swipeActions(allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                // Sistem kategorisi kontrolü
                                if kategori.localizationKey != nil {
                                    sistemKategoriUyarisi = true
                                } else {
                                    silinecekKategori = kategori
                                }
                            } label: {
                                Label("common.delete", systemImage: "trash")
                            }
                        }
                }
            }
            
            Section(LocalizedStringKey("categories.expense_categories")) {
                ForEach(giderKategorileri) { kategori in
                    kategoriSatiri(kategori: kategori)
                        .swipeActions(allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                // Sistem kategorisi kontrolü
                                if kategori.localizationKey != nil {
                                    sistemKategoriUyarisi = true
                                } else {
                                    silinecekKategori = kategori
                                }
                            } label: {
                                Label("common.delete", systemImage: "trash")
                            }
                        }
                }
            }
        }
        .navigationTitle(LocalizedStringKey("categories.title"))
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { yeniKategoriEkleGoster = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text(LocalizedStringKey("button.add_category"))
                    }
                }
            }
        }
        .sheet(isPresented: $yeniKategoriEkleGoster) { KategoriDuzenleView() }
        .alert(
            LocalizedStringKey("alert.delete_confirmation.title"),
            isPresented: Binding(isPresented: $silinecekKategori),
            presenting: silinecekKategori
        ) { kategori in
            Button(role: .destructive) {
                modelContext.delete(kategori)
                try? modelContext.save()
            } label: { Text("common.delete") }
        } message: { kategori in
            let dilKodu = appSettings.languageCode
            guard let path = Bundle.main.path(forResource: dilKodu, ofType: "lproj"),
                  let languageBundle = Bundle(path: path) else {
                return Text(kategori.isim)
            }

            let kategoriAdi = languageBundle.localizedString(forKey: kategori.localizationKey ?? kategori.isim, value: kategori.isim, table: nil)
            let formatString = languageBundle.localizedString(forKey: "alert.delete_category.message_format", value: "", table: nil)
            return Text(String(format: formatString, kategoriAdi))
        }
        // YENİ ALERT EKLE
        .alert(
            LocalizedStringKey("alert.system_category.title"),
            isPresented: $sistemKategoriUyarisi
        ) {
            Button("common.ok", role: .cancel) { }
        } message: {
            Text(LocalizedStringKey("alert.system_category.message"))
        }
    }
    
    @ViewBuilder
    private func kategoriSatiri(kategori: Kategori) -> some View {
        let isSystemCategory = kategori.localizationKey != nil
        
        HStack {
            Image(systemName: kategori.ikonAdi)
                .frame(width: 30, height: 30)
                .background(kategori.renk.opacity(0.2))
                .foregroundColor(kategori.renk)
                .cornerRadius(6)
            Text(LocalizedStringKey(kategori.localizationKey ?? kategori.isim))
        }
        .opacity(isSystemCategory ? 0.7 : 1.0)
        .overlay(alignment: .trailing) {
            // Sistem kategorileri için de NavigationLink aktif
            NavigationLink(destination: KategoriDuzenleView(kategori: kategori)) {
                EmptyView()
            }.opacity(0)
        }
    }
}
