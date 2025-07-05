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
    @EnvironmentObject var entitlementManager: EntitlementManager   // EKLE
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var seciliDilKodu: String
    @State private var cloudKitToggleAcik: Bool
    
    @State private var dilDegisikligiUyarisiGoster = false
    @State private var cloudKitDegisiklikUyarisiGoster = false
    @State private var showingDeleteConfirmationAlert = false
    
    @State private var isExporting = false
    @State private var shareableURL: ShareableURL?
    @State private var showPaywall = false                               // ⬅️ EKLENDİ
    
    init() {
        _seciliDilKodu = State(initialValue: AppSettings().languageCode)
        _cloudKitToggleAcik = State(initialValue: AppSettings().isCloudKitEnabled)
    }
    
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
                .disabled(!entitlementManager.hasPremiumAccess)          // ⛔️ tıklama
                .opacity(entitlementManager.hasPremiumAccess ? 1.0 : 0.4)
                .onTapGesture {
                    guard !entitlementManager.hasPremiumAccess else { return }
                    showPaywall = true                                   // Paywall tetikle
                }
                .padding(.vertical, 4)
            }
            Section(LocalizedStringKey("settings.section.data_management")) {
                
                // YENİ KOD: iCloud Yedekleme Toggle'ı
                HStack {
                    AyarIkonu(iconName: "icloud.fill", color: .cyan)
                    Toggle("settings.data.icloud_backup", isOn: $cloudKitToggleAcik)
                }
                .padding(.vertical, 4)
                
                // Veri Dışa Aktarma Butonu (Mevcut kodunuz)
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
                .padding(.vertical, 4) // <-- YENİ EKLENEN SATIR

                // Tüm Verileri Sil Butonu (Mevcut kodunuz)
                Button(role: .destructive) {
                    showingDeleteConfirmationAlert = true
                } label: {
                    HStack {
                        AyarIkonu(iconName: "trash.fill", color: .red)
                        Text(LocalizedStringKey("settings.data.delete_all"))
                    }
                }
                .padding(.vertical, 4) // <-- YENİ EKLENEN SATIR

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
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .onChange(of: entitlementManager.hasPremiumAccess) { yeniDurum in
            if yeniDurum { showPaywall = false }
        }

        // GÜNCELLENMİŞ ALERT: Dil değişikliği için
        .alert("settings.language_change.title", isPresented: $dilDegisikligiUyarisiGoster) {
            Button("alert.language_change.confirm_button") { // "Onayla"
                appSettings.languageCode = seciliDilKodu
                NotificationCenter.default.post(name: .appShouldRestart, object: nil)
            }
            Button("common.cancel", role: .cancel) {
                self.seciliDilKodu = appSettings.languageCode
            }
        } message: {
            Text("settings.language_change.message")
        }
        // YENİ ALERT: iCloud ayarı değişikliği için
        .alert("alert.icloud_toggle.title", isPresented: $cloudKitDegisiklikUyarisiGoster) {
            Button("settings.language_change.restart_button") {
                appSettings.isCloudKitEnabled = cloudKitToggleAcik
                NotificationCenter.default.post(name: .appShouldRestart, object: nil)
            }
            Button("common.cancel", role: .cancel) {
                self.cloudKitToggleAcik = appSettings.isCloudKitEnabled
            }
        } message: {
            Text("alert.icloud_toggle.message")
        }
        // Tüm verileri silme uyarısı (Mevcut kodunuz)
        .alert(LocalizedStringKey("alert.delete_all_data.title"), isPresented: $showingDeleteConfirmationAlert) {
            Button("common.confirm_delete", role: .destructive) {
                NotificationCenter.default.post(name: .appShouldDeleteAllData, object: nil)
                dismiss()
            }
            Button("common.cancel", role: .cancel) {}
        } message: {
            Text(LocalizedStringKey("alert.delete_all_data.message"))
        }
        // State değişikliklerini izleyen .onChange modifier'ları
        .onChange(of: seciliDilKodu) {
            if seciliDilKodu != appSettings.languageCode {
                dilDegisikligiUyarisiGoster = true
            }
        }
        .onChange(of: cloudKitToggleAcik) {
            if cloudKitToggleAcik != appSettings.isCloudKitEnabled {
                cloudKitDegisiklikUyarisiGoster = true
            }
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

extension Notification.Name {
    static let appShouldDeleteAllData = Notification.Name("appShouldDeleteAllData")
}
