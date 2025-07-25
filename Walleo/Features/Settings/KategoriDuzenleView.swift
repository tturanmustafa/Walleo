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
        // Mevcut ikonlar
        "tag.fill", "cart.fill", "fork.knife", "car.fill", "bolt.fill",
        "film.fill", "gift.fill", "house.fill", "airplane", "bus.fill",
        "fuelpump.fill", "gamecontroller.fill", "pills.fill", "tshirt.fill",
        "pawprint.fill", "ellipsis.circle.fill", "dollarsign.circle.fill",
        "chart.pie.fill", "banknote.fill", "briefcase.fill", "arrow.down.to.line.alt",
        
        // YENİ EKLENEN 15 İKON
        "heart.fill",              // Sağlık, bağış, sosyal yardım
        "book.fill",               // Eğitim, kitap
        "graduationcap.fill",      // Eğitim, kurs
        "sportscourt.fill",        // Spor, fitness
        "figure.walk",             // Yürüyüş, aktivite
        "bed.double.fill",         // Konaklama, otel
        "cup.and.saucer.fill",     // Kafe, kahve
        "music.note",              // Müzik, konser
        "paintbrush.fill",         // Sanat, hobi
        "wrench.fill",             // Tamir, bakım
        "scissors",                // Kuaför, güzellik
        "phone.fill",              // Telefon, iletişim
        "envelope.fill",           // Posta, kargo
        "creditcard.fill",         // Kredi kartı ödemeleri
        "building.2.fill"          // Kira, emlak
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
        
        // Validasyon
        guard !trimmedIsim.isEmpty || isSystemCategory else {
            Logger.log("Kategori adı boş olamaz", log: Logger.view, type: .error)
            return
        }
        
        // Renk validasyonu
        guard let hexColor = secilenRenk.toHex() else {
            Logger.log("Geçersiz renk seçimi", log: Logger.view, type: .error)
            return
        }
        
        do {
            if let kategori = kategori {
                // Güncelleme
                if !isSystemCategory {
                    kategori.isim = trimmedIsim
                }
                kategori.ikonAdi = ikonAdi
                kategori.renkHex = hexColor
            } else {
                // Yeni kategori
                let yeniKategori = Kategori(
                    isim: trimmedIsim,
                    ikonAdi: ikonAdi,
                    tur: secilenTur,
                    renkHex: hexColor,
                    localizationKey: nil
                )
                modelContext.insert(yeniKategori)
            }
            
            try modelContext.save()
            
            // Bildirim gönder
            NotificationCenter.default.post(name: .categoriesDidChange, object: nil)
            
            dismiss()
            
        } catch {
            Logger.log("Kategori kaydetme hatası: \(error)", log: Logger.data, type: .error)
        }
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
