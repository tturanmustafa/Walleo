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

    @State private var isExporting = false
    @State private var shareableURL: ShareableURL?

    @State private var showPaywall = false

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
                showPaywall: $showPaywall
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
            // Aile kontrolü kaldırıldı.
            // Sadece toggle'ın değeri, kayıtlı ayardan farklıysa uyarı göster.
            if cloudKitToggleAcik != appSettings.isCloudKitEnabled {
                cloudKitDegisiklikUyarisiGoster = true
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
                // Aile kontrolü kaldırıldı, direkt silme işlemi tetikleniyor.
                NotificationCenter.default.post(name: .appShouldDeleteAllData, object: nil)
                dismiss()
            }
            Button("common.cancel", role: .cancel) {}
        } message: {
            Text(LocalizedStringKey("alert.delete_all_data.message"))
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
                    Text("Deutsch").tag("de")
                    Text("Français").tag("fr")
                    Text("Español").tag("es")
                    Text("Italiano").tag("it")
                    Text("日本語").tag("ja")
                    Text("中文").tag("zh")
                    Text("Bahasa Indonesia").tag("id")
                    Text("हिन्दी").tag("hi")
                    Text("Tiếng Việt").tag("vi")
                    Text("ไทย").tag("th")
                    Text("Bahasa Melayu").tag("ms")
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
            .padding(.vertical, 4)
        }
    }
}

// MARK: - AyarlarView+VeriYonetimi.swift
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
        
    var body: some View {
        Section(LocalizedStringKey("settings.section.data_management")) {
            
                        
            // iCloud Toggle
            HStack {
                AyarIkonu(iconName: "icloud.fill", color: .cyan)
                Toggle("settings.data.icloud_backup", isOn: $cloudKitToggleAcik)
            }
            .padding(.vertical, 4)
            
            // Veri Dışa Aktar (CSV)
            Button(action: {
                if entitlementManager.hasPremiumAccess {
                    exportData()
                } else {
                    showPaywall = true
                }
            }) {
                HStack {
                    AyarIkonu(iconName: "square.and.arrow.up", color: .purple)
                    if isExporting {
                        Text(LocalizedStringKey("settings.data.exporting"))
                        Spacer()
                        ProgressView()
                    } else {
                        Text(LocalizedStringKey("settings.data.export"))
                        if !entitlementManager.hasPremiumAccess {
                            Spacer()
                            Image(systemName: "crown.fill")
                                .foregroundColor(.yellow)
                                .font(.footnote)
                        }
                    }
                }
            }
            .disabled(isExporting)
            .foregroundColor(.primary)
            .padding(.vertical, 4)
            
            // Detaylı PDF Rapor Oluştur
            NavigationLink(destination: PDFReportDatePicker().environmentObject(appSettings)) {
                HStack {
                    AyarIkonu(iconName: "doc.richtext.fill", color: .orange)
                    Text(LocalizedStringKey("settings.data.pdf_report"))
                    if !entitlementManager.hasPremiumAccess {
                        Spacer()
                        Image(systemName: "crown.fill")
                            .foregroundColor(.yellow)
                            .font(.footnote)
                    }
                }
            }
            .disabled(!entitlementManager.hasPremiumAccess)
            .foregroundColor(entitlementManager.hasPremiumAccess ? .primary : .secondary)
            .onTapGesture {
                if !entitlementManager.hasPremiumAccess {
                    showPaywall = true
                }
            }
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
    }
    
    // MARK: - Helpers
    // VeriYonetimiBolumu içindeki exportData fonksiyonunu güncelleyin
    private func exportData() {
        isExporting = true
        
        // İşlemleri çek
        let islemDescriptor = FetchDescriptor<Islem>(sortBy: [SortDescriptor(\.tarih, order: .reverse)])
        guard let islemler = try? modelContext.fetch(islemDescriptor) else {
            isExporting = false
            Logger.log("Dışa aktarma için işlemler çekilemedi.", log: Logger.service, type: .error)
            return
        }
        
        // Transferleri çek
        let transferDescriptor = FetchDescriptor<Transfer>(sortBy: [SortDescriptor(\.tarih, order: .reverse)])
        let transferler = (try? modelContext.fetch(transferDescriptor)) ?? []
        
        // Hesapları çek
        let hesapDescriptor = FetchDescriptor<Hesap>()
        let hesaplar = (try? modelContext.fetch(hesapDescriptor)) ?? []
        
        DispatchQueue.global(qos: .userInitiated).async {
            // ZIP içinde CSV'ler oluştur
            guard let zipURL = ExportService.generateExportZip(
                islemler: islemler,
                transferler: transferler,
                hesaplar: hesaplar,
                languageCode: appSettings.languageCode
            ) else {
                DispatchQueue.main.async {
                    self.isExporting = false
                    Logger.log("Export ZIP oluşturulamadı.", log: Logger.service, type: .error)
                }
                return
            }
            
            DispatchQueue.main.async {
                self.shareableURL = ShareableURL(url: zipURL)
                self.isExporting = false
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
