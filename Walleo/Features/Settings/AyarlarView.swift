import SwiftUI
import SwiftData

// Paylaşım Ekranı için URL'i Identifiable yapan yardımcı struct
struct ShareableURL: Identifiable {
    let id = UUID()
    let url: URL
}

// Ayarlar menüsündeki ikonları oluşturan yardımcı struct
struct AyarIkonu: View {
    let iconName: String
    let color: Color
    
    var body: some View {
        Image(systemName: iconName)
            .font(.callout)
            .foregroundColor(.white)
            .frame(width: 32, height: 32)
            .background(color)
            .cornerRadius(7)
    }
}

struct AyarlarView: View {
    @EnvironmentObject var appSettings: AppSettings
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    
    // YEREL STATE: Picker artık sadece bu geçici state'i değiştirecek.
    @State private var seciliDilKodu: String = "tr"
    
    @State private var dilDegisikligiUyarisiGoster = false
    
    @State private var isExporting = false
    @State private var shareableURL: ShareableURL?
    
    var body: some View {
        Form {
            Section(LocalizedStringKey("settings.section_general")) {
                // Tema Ayarı
                HStack {
                    AyarIkonu(iconName: "circle.righthalf.filled", color: .gray)
                    Text(LocalizedStringKey("settings.theme"))
                    Spacer()
                    Picker("Tema", selection: $appSettings.colorSchemeValue) {
                        Text(LocalizedStringKey("settings.theme_system")).tag(0)
                        Text(LocalizedStringKey("settings.theme_light")).tag(1)
                        Text(LocalizedStringKey("settings.theme_dark")).tag(2)
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
                .padding(.vertical, 4)
                
                // Dil Ayarı
                HStack {
                    AyarIkonu(iconName: "globe", color: .blue)
                    Text(LocalizedStringKey("settings.language"))
                    Spacer()
                    // Picker artık yerel 'seciliDilKodu' state'ine bağlı
                    Picker("Dil", selection: $seciliDilKodu) {
                        Text("Türkçe").tag("tr")
                        Text("English").tag("en")
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
                .padding(.vertical, 4)
                
                // Para Birimi Ayarı
                HStack {
                    AyarIkonu(iconName: "coloncurrencysign.circle.fill", color: .green)
                    Text(LocalizedStringKey("settings.currency"))
                    Spacer()
                    Picker("settings.currency", selection: $appSettings.currencyCode) {
                        ForEach(Currency.allCases) { currency in
                            (Text(currency.symbol) + Text("  ") + Text(LocalizedStringKey(currency.localizedNameKey)))
                                .tag(currency.rawValue)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
                .padding(.vertical, 4)
                
                // Kategori Yönetimi Linki
                NavigationLink(destination: KategoriYonetimView()) {
                    AyarIkonu(iconName: "folder.fill", color: .orange)
                    Text(LocalizedStringKey("settings.manage_categories"))
                }
                .padding(.vertical, 4)
                
                // Bildirim Ayarları Linki
                NavigationLink(destination: BildirimAyarlariView()) {
                    AyarIkonu(iconName: "bell.badge.fill", color: .red)
                    Text(LocalizedStringKey("settings.notifications"))
                }
                .padding(.vertical, 4)
            }
            
            Section(LocalizedStringKey("settings.section.data_management")) {
                Button(action: exportData) {
                    HStack {
                        AyarIkonu(iconName: "square.and.arrow.up", color: .purple)
                        
                        if isExporting {
                            Text(LocalizedStringKey("settings.data.exporting"))
                            Spacer()
                            ProgressView()
                        } else {
                            Text(LocalizedStringKey("settings.data.export"))
                        }
                    }
                }
                .disabled(isExporting)
                .foregroundColor(.primary)
            }
            
            Section(LocalizedStringKey("settings.section_info")) {
                HStack {
                    Text(LocalizedStringKey("settings.version"))
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle(LocalizedStringKey("settings.title"))
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(LocalizedStringKey("common.done")) {
                    dismiss()
                }
            }
        }
        .sheet(item: $shareableURL) { wrapper in
            ActivityView(activityItems: [wrapper.url])
        }
        // View ilk açıldığında yerel state'i mevcut ayarla eşitle
        .onAppear {
            self.seciliDilKodu = appSettings.languageCode
        }
        // Yerel state değiştiğinde ve kalıcı ayardan farklıysa uyarıyı göster
        .onChange(of: seciliDilKodu) {
            if seciliDilKodu != appSettings.languageCode {
                dilDegisikligiUyarisiGoster = true
            }
        }
        // Dil değişikliği için uyarı (alert)
        .alert("settings.language_change.title", isPresented: $dilDegisikligiUyarisiGoster) {
            Button("settings.language_change.restart_button", role: .destructive) {
                // Kullanıcı onaylarsa yeni dili kalıcı olarak kaydet
                appSettings.languageCode = seciliDilKodu
                // ve yeniden başlatma bildirimini gönder
                NotificationCenter.default.post(name: .appShouldRestart, object: nil)
            }
            Button("common.cancel", role: .cancel) {
                // Kullanıcı vazgeçerse yerel state'i eski, kalıcı haline getir
                self.seciliDilKodu = appSettings.languageCode
            }
        } message: {
            Text("settings.language_change.message")
        }
    }
    
    private func exportData() {
        isExporting = true
        
        let descriptor = FetchDescriptor<Islem>(sortBy: [SortDescriptor(\.tarih, order: .reverse)])
        guard let islemler = try? modelContext.fetch(descriptor) else {
            isExporting = false
            Logger.log("Dışa aktarma için işlemler çekilemedi.", log: Logger.service, type: .error)
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let csvString = ExportService.generateCSV(from: islemler, languageCode: appSettings.languageCode)
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("Walleo_Export.csv")
            
            do {
                try csvString.write(to: tempURL, atomically: true, encoding: .utf8)
                
                DispatchQueue.main.async {
                    self.shareableURL = ShareableURL(url: tempURL)
                    self.isExporting = false
                }
            } catch {
                Logger.log("CSV dosyası geçici olarak kaydedilirken hata oluştu: \(error.localizedDescription)", log: Logger.service, type: .error)
                DispatchQueue.main.async {
                    self.isExporting = false
                }
            }
        }
    }
}

// Uygulamanın yeniden başlatılması gerektiğini bildiren özel Notification.Name
// Bu extension artık AyarlarView içinde tanımlı olduğu için başka bir yerde olmasına gerek yok.
// Eğer başka bir dosyada da kullanılacaksa global bir yere taşınabilir.
