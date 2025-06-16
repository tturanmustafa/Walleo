import SwiftUI
import SwiftData

struct KategoriDuzenleView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss

    // Düzenleme için
    var kategori: Kategori?

    @State private var isim: String = ""
    @State private var ikonAdi: String = "tag.fill"
    @State private var secilenTur: IslemTuru = .gider
    @State private var secilenRenk: Color = .blue
    
    // İkon listesini genişlettik
    let ikonlar = [
        "tag.fill", "cart.fill", "fork.knife", "car.fill", "bolt.fill", "film.fill", "gift.fill", "house.fill", "airplane", "bus.fill", "fuelpump.fill", "gamecontroller.fill", "pills.fill", "tshirt.fill", "pawprint.fill", "ellipsis.circle.fill",
        "dollarsign.circle.fill", "chart.pie.fill", "banknote.fill", "briefcase.fill", "arrow.down.to.line.alt"
    ]

    var body: some View {
        NavigationStack {
            Form {
                if kategori == nil { // Sadece yeni kategori eklerken tür seçilebilir
                    Picker("Tür", selection: $secilenTur) {
                        Text("Gider").tag(IslemTuru.gider)
                        Text("Gelir").tag(IslemTuru.gelir)
                    }
                    .pickerStyle(.segmented)
                }
                
                TextField("Kategori Adı", text: $isim)
                
                // YENİ: Renk Seçici
                ColorPicker("Kategori Rengi", selection: $secilenRenk, supportsOpacity: false)
                
                Section("İkon Seç") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 16) {
                        ForEach(ikonlar, id: \.self) { ikon in
                            Image(systemName: ikon)
                                .font(.title2)
                                .foregroundColor(ikonAdi == ikon ? .primary : .secondary)
                                .frame(width: 44, height: 44)
                                .background(ikonAdi == ikon ? secilenRenk.opacity(0.2) : Color(.systemGray6))
                                .cornerRadius(8)
                                .onTapGesture {
                                    ikonAdi = ikon
                                }
                        }
                    }
                }
            }
            .navigationTitle(kategori == nil ? "Yeni Kategori" : "Kategoriyi Düzenle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") {
                        kaydet()
                    }
                    .disabled(isim.isEmpty)
                }
            }
            .onAppear(perform: formuDoldur)
        }
    }
    
    private func formuDoldur() {
        if let kategori = kategori {
            self.isim = kategori.isim
            self.ikonAdi = kategori.ikonAdi
            self.secilenTur = kategori.tur
            self.secilenRenk = kategori.renk
        }
    }
    
    private func kaydet() {
        if let kategori = kategori {
            // Düzenleme
            kategori.isim = isim
            kategori.ikonAdi = ikonAdi
            kategori.renkHex = secilenRenk.toHex() ?? "#FFFFFF"
        } else {
            // Yeni Ekleme
            let yeniKategori = Kategori(isim: isim, ikonAdi: ikonAdi, tur: secilenTur, renkHex: secilenRenk.toHex() ?? "#FFFFFF")
            modelContext.insert(yeniKategori)
        }
        dismiss()
    }
}

// Color'ı Hex'e çevirmek için ikinci yardımcı
extension Color {
    func toHex() -> String? {
        guard let components = cgColor?.components, components.count >= 3 else {
            return nil
        }
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        return String(format: "#%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255))
    }
}
