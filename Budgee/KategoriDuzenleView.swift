import SwiftUI
import SwiftData

struct KategoriDuzenleView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss

    var kategori: Kategori?

    @State private var isim: String = ""
    @State private var ikonAdi: String = "tag.fill"
    @State private var secilenTur: IslemTuru = .gider
    @State private var secilenRenk: Color = .blue
    
    let ikonlar = [
        "tag.fill", "cart.fill", "fork.knife", "car.fill", "bolt.fill", "film.fill", "gift.fill", "house.fill", "airplane", "bus.fill", "fuelpump.fill", "gamecontroller.fill", "pills.fill", "tshirt.fill", "pawprint.fill", "ellipsis.circle.fill",
        "dollarsign.circle.fill", "chart.pie.fill", "banknote.fill", "briefcase.fill", "arrow.down.to.line.alt"
    ]
    
    private var navigationTitleKey: LocalizedStringKey {
        kategori == nil ? "categories.new" : "categories.edit"
    }

    var body: some View {
        NavigationStack {
            Form {
                if kategori == nil {
                    Picker("common.type", selection: $secilenTur) {
                        Text("common.expense").tag(IslemTuru.gider)
                        Text("common.income").tag(IslemTuru.gelir)
                    }
                    .pickerStyle(.segmented)
                }
                
                TextField("categories.name", text: $isim)
                
                ColorPicker("categories.color", selection: $secilenRenk, supportsOpacity: false)
                
                Section("categories.select_icon") {
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
            .navigationTitle(navigationTitleKey)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save") {
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
            kategori.isim = isim
            kategori.ikonAdi = ikonAdi
            kategori.renkHex = secilenRenk.toHex() ?? "#FFFFFF"
        } else {
            let yeniKategori = Kategori(isim: isim, ikonAdi: ikonAdi, tur: secilenTur, renkHex: secilenRenk.toHex() ?? "#FFFFFF")
            modelContext.insert(yeniKategori)
        }
        dismiss()
    }
}

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
