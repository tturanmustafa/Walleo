// Dosya Adı: KategoriYonetimView.swift

import SwiftUI
import SwiftData

struct KategoriYonetimView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Kategori.isim) private var kategoriler: [Kategori]
    @State private var yeniKategoriEkleGoster = false

    // DÜZELTME: Kategorileri türe göre ayırmak için hesaplanmış değişkenler kullanıyoruz.
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
                }
                .onDelete { indexSet in deleteKategori(at: indexSet, for: .gelir) }
            }
            
            Section(LocalizedStringKey("categories.expense_categories")) {
                ForEach(giderKategorileri) { kategori in
                    kategoriSatiri(kategori: kategori)
                }
                .onDelete { indexSet in deleteKategori(at: indexSet, for: .gider) }
            }
        }
        .navigationTitle(LocalizedStringKey("categories.title"))
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { yeniKategoriEkleGoster = true }) { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $yeniKategoriEkleGoster) { KategoriDuzenleView() }
    }
    
    // YENİ: Tekrarı önlemek için ortak bir satır view'ı oluşturduk.
    @ViewBuilder
    private func kategoriSatiri(kategori: Kategori) -> some View {
        // "Kredi Ödemesi" bir sistem kategorisidir, düzenlenemez.
        let isSystemCategory = kategori.isim == "Kredi Ödemesi"
        
        HStack {
            Image(systemName: kategori.ikonAdi)
                .frame(width: 30, height: 30)
                .background(kategori.renk.opacity(0.2))
                .foregroundColor(kategori.renk)
                .cornerRadius(6)
            Text(LocalizedStringKey(kategori.localizationKey ?? kategori.isim))
        }
        .opacity(isSystemCategory ? 0.5 : 1.0) // Sistem kategorisini soluk göster
        .listRowSeparator(isSystemCategory ? .hidden : .visible) // Ayırıcı çizgisini gizle
        .overlay(alignment: .trailing) {
            if !isSystemCategory {
                // Sadece normal kategoriler için düzenleme linki ve ikonu göster
                NavigationLink(destination: KategoriDuzenleView(kategori: kategori)) {
                    EmptyView()
                }.opacity(0) // Linki görünmez yap, ama çalışsın
            }
        }
    }
    
    private func deleteKategori(at offsets: IndexSet, for tur: IslemTuru) {
        // Silinecek kategorileri belirle
        var kategorilerToDelete: [Kategori] = []
        let sourceList = (tur == .gelir) ? gelirKategorileri : giderKategorileri
        
        offsets.forEach { index in
            let kategori = sourceList[index]
            // "Kredi Ödemesi" kategorisinin silinmesini engelle
            if kategori.isim != "Kredi Ödemesi" {
                kategorilerToDelete.append(kategori)
            }
        }
        
        // Silme işlemini yap
        for kategori in kategorilerToDelete {
            modelContext.delete(kategori)
        }
    }
}
