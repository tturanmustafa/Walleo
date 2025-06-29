import SwiftUI
import SwiftData

struct ButceEkleDuzenleView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appSettings: AppSettings
    
    var duzenlenecekButce: Butce?

    @State private var isim: String = ""
    @State private var limitString: String = ""
    @State private var secilenKategoriIDleri: Set<UUID> = []

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
                    // --- DÜZELTME BURADA ---
                    LabeledTextField(
                        label: "form.label.budget_name", // Yeni etiket anahtarı
                        placeholder: "budget.name_placeholder", // Orijinal, açıklayıcı anahtar
                        text: $isim
                    )
                    
                    VStack(alignment: .leading) {
                        // --- DÜZELTME BURADA ---
                        LabeledAmountField(
                            label: "form.label.budget_limit", // Yeni etiket anahtarı
                            placeholder: "budget.limit_placeholder", // Orijinal, açıklayıcı anahtar
                            valueString: $limitString,
                            isInvalid: $isLimitGecersiz,
                            locale: Locale(identifier: appSettings.languageCode)
                        )
                        if isLimitGecersiz {
                            Text("validation.error.invalid_amount_format")
                                .font(.caption).foregroundColor(.red).padding(.top, 2)
                        }
                    }
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
        self.isLimitGecersiz = false
        if let kategoriler = butce.kategoriler {
            self.secilenKategoriIDleri = Set(kategoriler.map { $0.id })
        }
    }
    
    private func kaydet() {
        let secilenKategoriler = tumKategoriler.filter { secilenKategoriIDleri.contains($0.id) }
        let limit = stringToDouble(limitString, locale: Locale(identifier: appSettings.languageCode))
        
        if let butce = duzenlenecekButce {
            butce.isim = isim
            butce.limitTutar = limit
            butce.kategoriler = secilenKategoriler
        } else {
            let yeniButce = Butce(isim: isim, limitTutar: limit, kategoriler: secilenKategoriler)
            modelContext.insert(yeniButce)
        }
        
        dismiss()
    }
}
