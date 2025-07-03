import SwiftUI
import SwiftData

struct KategoriDuzenleView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appSettings: AppSettings

    // Bu özellik, dışarıdan bir kategori gelip gelmediğini tutar.
    var kategori: Kategori?

    // @State değişkenleri artık init içinde ayarlanacak.
    @State private var isim: String
    @State private var ikonAdi: String
    @State private var secilenTur: IslemTuru
    @State private var secilenRenk: Color
    
    // --- YENİ VE DOĞRU YAKLAŞIM: INIT METODU ---
    // Bu başlatıcı, view oluşturulurken SADECE BİR KEZ çalışır.
    init(kategori: Kategori? = nil) {
        self.kategori = kategori
        
        if let k = kategori {
            // EĞER DÜZENLEME MODUNDAYSAK:
            // State'i mevcut kategorinin verileriyle başlat.
            _isim = State(initialValue: k.isim)
            _ikonAdi = State(initialValue: k.ikonAdi)
            _secilenTur = State(initialValue: k.tur)
            _secilenRenk = State(initialValue: k.renk)
        } else {
            // EĞER EKLEME MODUNDAYSAK:
            // State'i varsayılan değerlerle başlat.
            _isim = State(initialValue: "")
            _ikonAdi = State(initialValue: "tag.fill")
            _secilenTur = State(initialValue: .gider)
            _secilenRenk = State(initialValue: Color(red: 0, green: 0.478, blue: 1))
        }
    }
    
    private var isSystemCategory: Bool {
        kategori?.localizationKey != nil
    }
    
    let ikonlar = [
        "tag.fill", "cart.fill", "fork.knife", "car.fill", "bolt.fill", "film.fill", "gift.fill", "house.fill", "airplane", "bus.fill", "fuelpump.fill", "gamecontroller.fill", "pills.fill", "tshirt.fill", "pawprint.fill", "ellipsis.circle.fill", "dollarsign.circle.fill", "chart.pie.fill", "banknote.fill", "briefcase.fill", "arrow.down.to.line.alt"
    ]
    
    private var navigationTitleKey: LocalizedStringKey {
        kategori == nil ? "categories.new" : "categories.edit"
    }

    var body: some View {
        NavigationStack {
            Form {
                // ... Form'un içeriği tamamen aynı kalıyor ...
                if kategori == nil {
                    Section {
                        Picker("common.type", selection: $secilenTur) {
                            Text(LocalizedStringKey("common.expense")).tag(IslemTuru.gider)
                            Text(LocalizedStringKey("common.income")).tag(IslemTuru.gelir)
                        }
                        .pickerStyle(.segmented)
                    }
                }
                
                Section {
                    TextField("categories.name", text: $isim)
                        .disabled(isSystemCategory)
                        .foregroundColor(isSystemCategory ? .secondary : .primary)

                    ColorPicker("categories.color", selection: $secilenRenk, supportsOpacity: false)
                }
                
                Section("categories.select_icon") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 16) {
                        ForEach(ikonlar, id: \.self) { ikon in
                            Image(systemName: ikon)
                                .font(.title2)
                                .foregroundColor(ikonAdi == ikon ? secilenRenk : .secondary)
                                .frame(width: 44, height: 44)
                                .background(ikonAdi == ikon ? secilenRenk.opacity(0.2) : Color(.systemGray6))
                                .cornerRadius(8)
                                .onTapGesture {
                                    ikonAdi = ikon
                                }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle(navigationTitleKey)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Toolbar da tamamen aynı kalıyor
                if kategori == nil {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("common.cancel") { dismiss() }
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save") {
                        kaydet()
                    }
                    .disabled(isim.trimmingCharacters(in: .whitespaces).isEmpty && !isSystemCategory)
                }
            }
            // ARTIK .onAppear ve formuDoldur'a İHTİYACIMIZ YOK.
            // .onAppear(perform: formuDoldur) satırını siliyoruz.
        }
    }
    
    // ARTIK BU FONKSİYONA İHTİYACIMIZ YOK, SİLİNEBİLİR.
    /*
    private func formuDoldur() {
        //...
    }
    */
    
    // Kaydet fonksiyonu daha önce düzelttiğimiz doğru haliyle kalıyor.
    private func kaydet() {
        let trimmedIsim = isim.trimmingCharacters(in: .whitespaces)
        guard !trimmedIsim.isEmpty || isSystemCategory else { return }
        
        if let kategori = kategori {
            if !isSystemCategory {
                kategori.isim = trimmedIsim
            }
            kategori.ikonAdi = ikonAdi
            kategori.renkHex = secilenRenk.toHex() ?? "#FFFFFF"
        } else {
            let yeniKategori = Kategori(
                isim: trimmedIsim,
                ikonAdi: ikonAdi,
                tur: secilenTur,
                renkHex: secilenRenk.toHex() ?? "#FFFFFF",
                localizationKey: nil
            )
            modelContext.insert(yeniKategori)
        }
        
        do {
            try modelContext.save()
            NotificationCenter.default.post(name: .categoriesDidChange, object: nil)
        } catch {
            Logger.log("Kategori kaydedilirken hata oluştu: \(error.localizedDescription)", log: Logger.data, type: .error)
        }
        
        dismiss()
    }
}

// Bu extension da view içinde kalabilir, sorun yok.
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
