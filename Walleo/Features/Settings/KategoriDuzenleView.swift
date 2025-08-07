import SwiftUI
import SwiftData

struct KategoriDuzenleView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appSettings: AppSettings
    @EnvironmentObject var entitlementManager: EntitlementManager // YENİ

    // Bu özellik, dışarıdan bir kategori gelip gelmediğini tutar.
    var kategori: Kategori?
    var varsayilanTur: IslemTuru? // Başlangıç türü

    // @State değişkenleri artık init içinde ayarlanacak.
    @State private var isim: String
    @State private var ikonAdi: String
    @State private var secilenTur: IslemTuru
    @State private var secilenRenk: Color
    @State private var showPaywall = false // YENİ
    
    // --- YENİ VE DOĞRU YAKLAŞIM: INIT METODU ---
    // Bu başlatıcı, view oluşturulurken SADECE BİR KEZ çalışır.
    init(kategori: Kategori? = nil, varsayilanTur: IslemTuru? = nil) {
        self.kategori = kategori
        self.varsayilanTur = varsayilanTur
        
        if let k = kategori {
            _isim = State(initialValue: k.isim)
            _ikonAdi = State(initialValue: k.ikonAdi)
            _secilenTur = State(initialValue: k.tur)
            _secilenRenk = State(initialValue: k.renk)
        } else {
            _isim = State(initialValue: "")
            _ikonAdi = State(initialValue: "tag.fill")
            _secilenTur = State(initialValue: varsayilanTur ?? .gider)
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
    
    // YENİ: Kategori ekleme limiti kontrolü
    private func canAddCategory() -> Bool {
        // Düzenleme modundaysa izin ver
        if kategori != nil {
            return true
        }
        
        // Premium kullanıcılar sınırsız ekleyebilir
        if entitlementManager.hasPremiumAccess {
            return true
        }
        
        // Kullanıcı kategorilerini say
        let categoryDescriptor = FetchDescriptor<Kategori>(
            predicate: #Predicate { $0.localizationKey == nil }
        )
        let userCategoryCount = (try? modelContext.fetchCount(categoryDescriptor)) ?? 0
        
        // Metadata'yı kontrol et
        let metadataDescriptor = FetchDescriptor<AppMetadata>()
        guard let metadata = try? modelContext.fetch(metadataDescriptor).first else {
            return userCategoryCount < 5 // Metadata yoksa varsayılan limit
        }
        
        // İlk kez kontrol ediliyorsa, mevcut sayıyı kaydet
        if metadata.initialUserCategoryCount == -1 {
            metadata.initialUserCategoryCount = userCategoryCount
            try? modelContext.save()
        }
        
        // Kullanıcı başlangıçtaki sayı + 5'ten fazla ekleyebilir mi?
        let allowedNewCategories = 5
        let maxAllowed = metadata.initialUserCategoryCount + allowedNewCategories
        
        return userCategoryCount < maxAllowed
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
            // YENİ: Paywall sheet
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        }
    }
    
    private func kaydet() {
        let trimmedIsim = isim.trimmingCharacters(in: .whitespaces)
        
        // Validasyon
        guard !trimmedIsim.isEmpty || isSystemCategory else {
            Logger.log("Kategori adı boş olamaz", log: Logger.view, type: .error)
            return
        }
        
        // YENİ: Yeni kategori eklenirken limit kontrolü
        if kategori == nil && !canAddCategory() {
            showPaywall = true
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
