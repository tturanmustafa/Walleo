import SwiftUI
import SwiftData

struct ButceEkleDuzenleView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appSettings: AppSettings // Dil ayarlarına erişim için eklendi
    
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
        // Uygulama içinden seçilen dil kodunu al
        let dilKodu = appSettings.languageCode
        
        // Bu dil koduna ait dil paketini (bundle) bul
        guard let path = Bundle.main.path(forResource: dilKodu, ofType: "lproj"),
              let languageBundle = Bundle(path: path) else {
            // Eğer paket bulunamazsa, en azından ham veriyi göster
            return tumKategoriler
                .filter { secilenKategoriIDleri.contains($0.id) }
                .map { $0.localizationKey ?? $0.isim }
                .joined(separator: ", ")
        }
        
        // Çeviriyi, bulduğumuz bu özel dil paketi üzerinden yap
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
                    TextField(LocalizedStringKey("budgets.form.name_placeholder"), text: $isim)
                    
                    VStack(alignment: .leading) {
                        TextField(LocalizedStringKey("budgets.form.limit_amount"), text: $limitString)
                            .keyboardType(.decimalPad)
                            .validateAmountInput(text: $limitString, isInvalid: $isLimitGecersiz)
                            .overlay(
                                RoundedRectangle(cornerRadius: 5)
                                    .stroke(isLimitGecersiz ? Color.red : Color.clear, lineWidth: 1)
                            )
                        
                        if isLimitGecersiz {
                            Text(LocalizedStringKey("validation.error.invalid_amount_format"))
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
        self.limitString = String(butce.limitTutar)
        if let kategoriler = butce.kategoriler {
            self.secilenKategoriIDleri = Set(kategoriler.map { $0.id })
        }
    }
    
    private func kaydet() {
        let secilenKategoriler = tumKategoriler.filter { secilenKategoriIDleri.contains($0.id) }
        
        if let butce = duzenlenecekButce {
            butce.isim = isim
            butce.limitTutar = Double(limitString.replacingOccurrences(of: ",", with: ".")) ?? 0
            butce.kategoriler = secilenKategoriler
        } else {
            let limit = Double(limitString.replacingOccurrences(of: ",", with: ".")) ?? 0
            let yeniButce = Butce(isim: isim, limitTutar: limit, kategoriler: secilenKategoriler)
            modelContext.insert(yeniButce)
        }
        
        dismiss()
    }
}
