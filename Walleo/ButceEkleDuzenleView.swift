import SwiftUI
import SwiftData

struct ButceEkleDuzenleView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appSettings: AppSettings
    
    var duzenlenecekButce: Butce?

    // State değişkenleri
    @State private var isim: String = ""
    @State private var limitString: String = ""
    @State private var secilenKategoriIDleri: Set<UUID> = []
    
    // --- YENİ EKLENEN STATE'LER ---
    @State private var otomatikYenile: Bool = true
    @State private var devredenBakiyeEtkin: Bool = false

    @State private var isLimitGecersiz = false
    @State private var kategoriSecimGoster = false
    
    @Query private var tumKategoriler: [Kategori]

    private var isFormValid: Bool {
        !isim.trimmingCharacters(in: .whitespaces).isEmpty &&
        !limitString.isEmpty &&
        !isLimitGecersiz &&
        !secilenKategoriIDleri.isEmpty
    }
    
    private var seciliKategoriIsimleri: String {
        let dilKodu = appSettings.languageCode
        
        guard let path = Bundle.main.path(forResource: dilKodu, ofType: "lproj"),
              let languageBundle = Bundle(path: path) else {
            return tumKategoriler
                .filter { secilenKategoriIDleri.contains($0.id) }
                .map { $0.localizationKey ?? $0.isim }
                .joined(separator: ", ")
        }
        
        return tumKategoriler
            .filter { secilenKategoriIDleri.contains($0.id) }
            .map { kategori in
                languageBundle.localizedString(forKey: kategori.localizationKey ?? kategori.isim, value: kategori.isim, table: nil)
            }
            .joined(separator: ", ")
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledTextField(
                        label: "form.label.budget_name",
                        placeholder: "budget.name_placeholder",
                        text: $isim
                    )
                    
                    LabeledAmountField(
                        label: "form.label.budget_limit",
                        placeholder: "budget.limit_placeholder",
                        valueString: $limitString,
                        isInvalid: $isLimitGecersiz,
                        locale: Locale(identifier: appSettings.languageCode)
                    )
                }
                
                Section {
                    Button(action: { kategoriSecimGoster = true }) {
                        HStack {
                            Text(LocalizedStringKey("common.categories"))
                            Spacer()
                            if secilenKategoriIDleri.isEmpty {
                                Text(LocalizedStringKey("budgets.form.select_categories"))
                                    .foregroundColor(.secondary)
                            } else {
                                Text(seciliKategoriIsimleri)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            Image(systemName: "chevron.right")
                                .font(.caption.bold())
                                .foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.primary)
                }
                
                Section(header: Text("budget.automation_settings")) {
                    HStack {
                        Text(LocalizedStringKey("budget.form.auto_renew"))
                        Spacer() // Metin ve anahtar arasına boşluk ekleyerek sağa iter.
                        Toggle("", isOn: $otomatikYenile.animation())
                            .labelsHidden() // Toggle'ın kendi iç etiketini gizler.
                    }
                    
                    // --- 2. DEVREDEN BAKİYE SATIRI (YENİ YAPI) ---
                    if otomatikYenile {
                        HStack {
                            Text(LocalizedStringKey("budget.form.rollover_balance"))
                            Spacer() // Metin ve anahtar arasına boşluk ekleyerek sağa iter.
                            Toggle("", isOn: $devredenBakiyeEtkin)
                                .labelsHidden() // Toggle'ın kendi iç etiketini gizler.
                        }
                    }
                }
            }
            .navigationTitle(duzenlenecekButce == nil ? LocalizedStringKey("budgets.add.title") : LocalizedStringKey("budgets.edit.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("common.save")) {
                        kaydet()
                    }
                    .disabled(!isFormValid)
                }
            }
            .sheet(isPresented: $kategoriSecimGoster) {
                KategoriMultiSecimView(secilenKategoriIDleri: $secilenKategoriIDleri)
            }
            .onAppear(perform: formuDoldur)
        }
    }
    
    private func formuDoldur() {
        guard let butce = duzenlenecekButce else { return }
        self.isim = butce.isim
        self.limitString = formatAmountForEditing(amount: butce.limitTutar, localeIdentifier: appSettings.languageCode)
        self.otomatikYenile = butce.otomatikYenile
        self.devredenBakiyeEtkin = butce.devredenBakiyeEtkin
        if let kategoriler = butce.kategoriler {
            self.secilenKategoriIDleri = Set(kategoriler.map { $0.id })
        }
    }
    
    private func kaydet() {
        let limit = stringToDouble(limitString, locale: Locale(identifier: appSettings.languageCode))
        let secilenKategoriler = tumKategoriler.filter { secilenKategoriIDleri.contains($0.id) }
        
        if let butce = duzenlenecekButce {
            // Güncelleme
            butce.isim = isim.trimmingCharacters(in: .whitespaces)
            butce.limitTutar = limit
            butce.kategoriler = secilenKategoriler
            butce.otomatikYenile = otomatikYenile
            butce.devredenBakiyeEtkin = devredenBakiyeEtkin
        } else {
            // Yeni bütçe oluşturma
            let calendar = Calendar.current
            let ayinBasi = calendar.date(from: calendar.dateComponents([.year, .month], from: Date())) ?? Date()
            
            let yeniButce = Butce(
                isim: isim.trimmingCharacters(in: .whitespaces),
                limitTutar: limit,
                periyot: ayinBasi, // Bütçeyi bu ay için oluştur
                otomatikYenile: otomatikYenile,
                devredenBakiyeEtkin: devredenBakiyeEtkin,
                kategoriler: secilenKategoriler
            )
            modelContext.insert(yeniButce)
        }
        
        try? modelContext.save()
        dismiss()
    }
}
