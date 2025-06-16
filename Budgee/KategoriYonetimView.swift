import SwiftUI
import SwiftData

struct KategoriYonetimView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Kategori.isim) private var kategoriler: [Kategori]
    @State private var yeniKategoriEkleGoster = false

    var body: some View {
        List {
            Section("Gelir Kategorileri") {
                ForEach(kategoriler.filter { $0.tur == .gelir }) { kategori in
                    NavigationLink(destination: KategoriDuzenleView(kategori: kategori)) {
                        HStack {
                            Image(systemName: kategori.ikonAdi)
                                .frame(width: 30, height: 30)
                                .background(kategori.renk.opacity(0.2))
                                .foregroundColor(kategori.renk)
                                .cornerRadius(6)
                            Text(kategori.isim)
                        }
                    }
                }
                .onDelete { indexSet in
                    deleteKategori(at: indexSet, for: .gelir)
                }
            }
            
            Section("Gider Kategorileri") {
                ForEach(kategoriler.filter { $0.tur == .gider }) { kategori in
                    NavigationLink(destination: KategoriDuzenleView(kategori: kategori)) {
                        HStack {
                            Image(systemName: kategori.ikonAdi)
                                .frame(width: 30, height: 30)
                                .background(kategori.renk.opacity(0.2))
                                .foregroundColor(kategori.renk)
                                .cornerRadius(6)
                            Text(kategori.isim)
                        }
                    }
                }
                .onDelete { indexSet in
                    deleteKategori(at: indexSet, for: .gider)
                }
            }
        }
        .navigationTitle("Kategoriler")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { yeniKategoriEkleGoster = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $yeniKategoriEkleGoster) {
            KategoriDuzenleView()
        }
        .onAppear(perform: addDefaultCategoriesIfNeeded)
    }
    
    private func addDefaultCategoriesIfNeeded() {
        if kategoriler.isEmpty {
            // Gelir
            modelContext.insert(Kategori(isim: "Maaş", ikonAdi: "dollarsign.circle.fill", tur: .gelir, renkHex: "#34C759"))
            modelContext.insert(Kategori(isim: "Ek Gelir", ikonAdi: "chart.pie.fill", tur: .gelir, renkHex: "#007AFF"))
            modelContext.insert(Kategori(isim: "Yatırım", ikonAdi: "chart.line.uptrend.xyaxis", tur: .gelir, renkHex: "#AF52DE"))
            // Gider
            modelContext.insert(Kategori(isim: "Market", ikonAdi: "cart.fill", tur: .gider, renkHex: "#FF9500"))
            modelContext.insert(Kategori(isim: "Restoran", ikonAdi: "fork.knife", tur: .gider, renkHex: "#FF3B30"))
            modelContext.insert(Kategori(isim: "Ulaşım", ikonAdi: "car.fill", tur: .gider, renkHex: "#5E5CE6"))
            modelContext.insert(Kategori(isim: "Faturalar", ikonAdi: "bolt.fill", tur: .gider, renkHex: "#FFCC00"))
            modelContext.insert(Kategori(isim: "Eğlence", ikonAdi: "film.fill", tur: .gider, renkHex: "#32ADE6"))
            modelContext.insert(Kategori(isim: "Sağlık", ikonAdi: "pills.fill", tur: .gider, renkHex: "#64D2FF"))
            modelContext.insert(Kategori(isim: "Giyim", ikonAdi: "tshirt.fill", tur: .gider, renkHex: "#FF2D55"))
            modelContext.insert(Kategori(isim: "Ev", ikonAdi: "house.fill", tur: .gider, renkHex: "#A2845E"))
            modelContext.insert(Kategori(isim: "Hediye", ikonAdi: "gift.fill", tur: .gider, renkHex: "#BF5AF2"))
            modelContext.insert(Kategori(isim: "Diğer", ikonAdi: "ellipsis.circle.fill", tur: .gider, renkHex: "#8E8E93"))
        }
    }
    
    private func deleteKategori(at offsets: IndexSet, for tur: IslemTuru) {
        let filtrelenmisKategoriler = kategoriler.filter { $0.tur == tur }
        for index in offsets {
            let kategori = filtrelenmisKategoriler[index]
            modelContext.delete(kategori)
        }
    }
}
