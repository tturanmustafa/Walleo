// MARK: - AyarlarView.swift
// Ana görünüm: alt bileşenleri çağırır ve ortak state'i yönetir

import SwiftUI
import SwiftData

struct AyarlarView: View {
    @EnvironmentObject var appSettings: AppSettings
    @EnvironmentObject var entitlementManager: EntitlementManager
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var seciliDilKodu: String = AppSettings().languageCode
    @State private var cloudKitToggleAcik: Bool = AppSettings().isCloudKitEnabled

    @State private var dilDegisikligiUyarisiGoster = false
    @State private var cloudKitDegisiklikUyarisiGoster = false
    @State private var showingDeleteConfirmationAlert = false
    @State private var showFamilyActiveWarning = false
    @State private var showCloudKitFamilyWarning = false

    @State private var isExporting = false
    @State private var shareableURL: ShareableURL?

    @State private var showPaywall = false
    @State private var aileHesabiYonetimGoster = false

    var body: some View {
        Form {
            GenelAyarlarBolumu(
                seciliDilKodu: $seciliDilKodu,
                cloudKitToggleAcik: $cloudKitToggleAcik,
                showPaywall: $showPaywall
            )
            
            VeriYonetimiBolumu(
                seciliDilKodu: $seciliDilKodu,
                cloudKitToggleAcik: $cloudKitToggleAcik,
                isExporting: $isExporting,
                shareableURL: $shareableURL,
                showingDeleteConfirmationAlert: $showingDeleteConfirmationAlert,
                showPaywall: $showPaywall,
                aileHesabiYonetimGoster: $aileHesabiYonetimGoster,
                showCloudKitFamilyWarning: $showCloudKitFamilyWarning
            )
            
            BilgiBolumu()
        }
        .navigationTitle(LocalizedStringKey("settings.title"))
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(LocalizedStringKey("common.done")) { dismiss() }
            }
        }
        // TÜM SHEET'LER BURADA - TEK YERDE
        .sheet(item: $shareableURL) { wrapper in
            ActivityView(activityItems: [wrapper.url])
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .sheet(isPresented: $aileHesabiYonetimGoster) {
            AileHesabiYonetimView()
                .environmentObject(appSettings)
                .environmentObject(entitlementManager)
        }
        // CHANGE HANDLERS
        .onChange(of: entitlementManager.hasPremiumAccess) { _, yeniDurum in
            if yeniDurum {
                showPaywall = false
            }
        }
        .onChange(of: seciliDilKodu) { _, _ in
            if seciliDilKodu != appSettings.languageCode {
                dilDegisikligiUyarisiGoster = true
            }
        }
        .onChange(of: cloudKitToggleAcik) { _, _ in
            if cloudKitToggleAcik != appSettings.isCloudKitEnabled {
                // Aile hesabı kontrolü
                if !cloudKitToggleAcik && AileHesabiService.shared.mevcutAileHesabi != nil {
                    showCloudKitFamilyWarning = true
                    cloudKitToggleAcik = true // Toggle'ı geri aç
                } else {
                    cloudKitDegisiklikUyarisiGoster = true
                }
            }
        }
        // ALERTS
        .alert("settings.language_change.title", isPresented: $dilDegisikligiUyarisiGoster) {
            Button("alert.language_change.confirm_button") {
                appSettings.languageCode = seciliDilKodu
                NotificationCenter.default.post(name: .appShouldRestart, object: nil)
            }
            Button("common.cancel", role: .cancel) {
                self.seciliDilKodu = appSettings.languageCode
            }
        } message: {
            Text("settings.language_change.message")
        }
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
        .alert(LocalizedStringKey("alert.delete_all_data.title"), isPresented: $showingDeleteConfirmationAlert) {
            Button("common.confirm_delete", role: .destructive) {
                // Aile hesabı kontrolü
                if AileHesabiService.shared.mevcutAileHesabi != nil {
                    showFamilyActiveWarning = true
                } else {
                    NotificationCenter.default.post(name: .appShouldDeleteAllData, object: nil)
                    dismiss()
                }
            }
            Button("common.cancel", role: .cancel) {}
        } message: {
            Text(LocalizedStringKey("alert.delete_all_data.message"))
        }
        .alert("family.error.cannot_delete_with_family", isPresented: $showFamilyActiveWarning) {
            Button("common.ok", role: .cancel) {}
        } message: {
            Text("family.error.must_leave_family_first")
        }
        .alert("family.error.cannot_disable_icloud", isPresented: $showCloudKitFamilyWarning) {
            Button("common.ok", role: .cancel) {}
        } message: {
            Text("family.error.icloud_required_for_family")
        }
    }
}


// MARK: - GenelAyarlarBolumu.swift
struct GenelAyarlarBolumu: View {
    @EnvironmentObject var appSettings: AppSettings
    @EnvironmentObject var entitlementManager: EntitlementManager

    @Binding var seciliDilKodu: String
    @Binding var cloudKitToggleAcik: Bool
    @Binding var showPaywall: Bool

    var body: some View {
        Section(LocalizedStringKey("settings.section_general")) {
            // Tema
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

            // Dil
            HStack {
                AyarIkonu(iconName: "globe", color: .blue)
                Text(LocalizedStringKey("settings.language"))
                Spacer()
                Picker("Dil", selection: $seciliDilKodu) {
                    Text("Türkçe").tag("tr")
                    Text("English").tag("en")
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }
            .padding(.vertical, 4)

            // Para Birimi
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

            // Kategori Yönetimi
            NavigationLink(destination: KategoriYonetimView()) {
                AyarIkonu(iconName: "folder.fill", color: .orange)
                Text(LocalizedStringKey("settings.manage_categories"))
            }
            .padding(.vertical, 4)

            // Bildirim - ESKI KOD GİBİ AMA PAYWALL BINDING İLE
            NavigationLink(destination: BildirimAyarlariView()) {
                AyarIkonu(iconName: "bell.badge.fill", color: .red)
                Text(LocalizedStringKey("settings.notifications"))
            }
            .disabled(!entitlementManager.hasPremiumAccess)
            .opacity(entitlementManager.hasPremiumAccess ? 1.0 : 0.4)
            .onTapGesture {
                guard !entitlementManager.hasPremiumAccess else { return }
                showPaywall = true  // Ana view'daki state'i değiştir
            }
            .padding(.vertical, 4)
        }
    }
}

// MARK: - AyarlarView+VeriYonetimi.swift
struct VeriYonetimiBolumu: View {
    @EnvironmentObject var appSettings: AppSettings
    @EnvironmentObject var entitlementManager: EntitlementManager
    @Environment(\.modelContext) private var modelContext
    
    @Binding var seciliDilKodu: String
    @Binding var cloudKitToggleAcik: Bool
    @Binding var isExporting: Bool
    @Binding var shareableURL: ShareableURL?
    @Binding var showingDeleteConfirmationAlert: Bool
    @Binding var showPaywall: Bool
    @Binding var aileHesabiYonetimGoster: Bool
    @Binding var showCloudKitFamilyWarning: Bool
    
    @State private var aileHesabindanAyrilUyarisi = false
    @StateObject private var aileService = AileHesabiService.shared
    @StateObject private var cloudKit = CloudKitManager.shared
    
    var body: some View {
        Section(LocalizedStringKey("settings.section.data_management")) {
            
            // Aile Hesabı Yönetimi - Premium kontrolü kaldırıldı
            Button(action: {
                aileHesabiYonetimGoster = true
            }) {
                HStack {
                    AyarIkonu(iconName: "person.3.fill", color: .indigo)
                    VStack(alignment: .leading) {
                        Text(LocalizedStringKey("settings.family.manage"))
                        if let aileHesabi = aileService.mevcutAileHesabi {
                            HStack {
                                Text(aileHesabi.isim)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                if aileHesabi.adminID == cloudKit.currentUserID {
                                    Text("Admin")
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.accentColor.opacity(0.2))
                                        .cornerRadius(4)
                                }
                            }
                        }
                    }
                    Spacer()
                    if !aileService.bekleyenDavetler.isEmpty {
                        BadgeView(count: aileService.bekleyenDavetler.count)
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption.bold())
                        .foregroundColor(.secondary.opacity(0.5))
                }
            }
            .foregroundColor(.primary)
            .padding(.vertical, 4)
                        
            // iCloud Toggle
            HStack {
                AyarIkonu(iconName: "icloud.fill", color: .cyan)
                Toggle("settings.data.icloud_backup", isOn: $cloudKitToggleAcik)
            }
            .padding(.vertical, 4)
            
            // Veri Dışa Aktar
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
            .padding(.vertical, 4)
            
            // Verileri Sil
            Button(role: .destructive) {
                showingDeleteConfirmationAlert = true
            } label: {
                HStack {
                    AyarIkonu(iconName: "trash.fill", color: .red)
                    Text(LocalizedStringKey("settings.data.delete_all"))
                }
            }
            .padding(.vertical, 4)
        }
        .onAppear {
            aileService.configure(with: modelContext)
        }
    }
    
    // MARK: - Helpers
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

// MARK: - AyarlarView+BilgiBolumu.swift
struct BilgiBolumu: View {
    var body: some View {
        Section(LocalizedStringKey("settings.section_info")) {
            HStack {
                Text(LocalizedStringKey("settings.version"))
                Spacer()
                Text("1.0.0")
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - AyarIkonu.swift
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

// MARK: - ShareableURL.swift
struct ShareableURL: Identifiable {
    let id = UUID()
    let url: URL
}

// Mark
struct BadgeView: View {
    let count: Int
    
    var body: some View {
        Text("\(count)")
            .font(.caption2.bold())
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.red)
            .clipShape(Capsule())
    }
}

// MARK: - Notification Extensions
extension Notification.Name {
    static let appShouldDeleteAllData = Notification.Name("appShouldDeleteAllData")
    static let showPaywallRequested = Notification.Name("showPaywallRequested")
}
