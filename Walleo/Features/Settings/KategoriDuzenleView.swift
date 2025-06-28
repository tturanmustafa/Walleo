import SwiftUI
import SwiftData

struct KategoriDuzenleView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appSettings: AppSettings

    var kategori: Kategori?

    @State private var isim: String = ""
    @State private var ikonAdi: String = "tag.fill"
    @State private var secilenTur: IslemTuru = .gider
    @State private var secilenRenk: Color = .blue
    
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
            .onAppear(perform: formuDoldur)
        }
    }
    
    private func formuDoldur() {
        guard let kategori = kategori else { return }
        
        if let key = kategori.localizationKey {
            let languageCode = appSettings.languageCode
            if let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
               let languageBundle = Bundle(path: path) {
                self.isim = languageBundle.localizedString(forKey: key, value: kategori.isim, table: nil)
            } else {
                self.isim = kategori.isim
            }
        } else {
            self.isim = kategori.isim
        }
        
        self.ikonAdi = kategori.ikonAdi
        self.secilenTur = kategori.tur
        self.secilenRenk = kategori.renk
    }
    
    // DİKKAT: KAYDETME MANTIĞI GÜNCELLENDİ
    private func kaydet() {
        let trimmedIsim = isim.trimmingCharacters(in: .whitespaces)
        guard !trimmedIsim.isEmpty || isSystemCategory else { return }
        
        if let kategori = kategori {
            // DÜZENLEME MANTIĞI (Aynı kalıyor)
            if !isSystemCategory {
                kategori.isim = trimmedIsim
            }
            kategori.ikonAdi = ikonAdi
            kategori.renkHex = secilenRenk.toHex() ?? "#FFFFFF"
        } else {
            // YENİ KATEGORİ EKLEME MANTIĞI (Değişti)
            let yeniKategori = Kategori() // 1. Boş bir nesne yarat
            
            // 2. Özelliklerini tek tek ata
            yeniKategori.isim = trimmedIsim
            yeniKategori.ikonAdi = ikonAdi
            yeniKategori.tur = secilenTur
            yeniKategori.renkHex = secilenRenk.toHex() ?? "#FFFFFF"
            yeniKategori.localizationKey = nil // Kullanıcı tarafından oluşturulanların çeviri anahtarı olmaz.
            
            modelContext.insert(yeniKategori) // 3. Veritabanına ekle
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

// Color -> Hex çevrimi için olan extension'ı buraya taşıdım
// böylece bu View kendi kendine yetebilir hale geldi.
// Eğer bu extension başka yerlerde de kullanılıyorsa,
// Helpers.swift gibi merkezi bir dosyada tutulması daha doğrudur.
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
