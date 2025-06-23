import SwiftUI

struct AyarlarView: View {
    @EnvironmentObject var appSettings: AppSettings
    @Environment(\.dismiss) var dismiss
    
    // Başlığı manuel olarak güncellemek için.
    @State private var currentTitle: String = ""

    var body: some View {
        Form {
            Section(LocalizedStringKey("settings.section_general")) {
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
                
                HStack {
                    AyarIkonu(iconName: "globe", color: .blue)
                    Text(LocalizedStringKey("settings.language"))
                    Spacer()
                    Picker("Dil", selection: $appSettings.languageCode) {
                        Text("Türkçe").tag("tr")
                        Text("English").tag("en")
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
                .padding(.vertical, 4)
                
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
                
                NavigationLink(destination: KategoriYonetimView()) {
                    AyarIkonu(iconName: "folder.fill", color: .orange)
                    Text(LocalizedStringKey("settings.manage_categories"))
                }
                .padding(.vertical, 4)
                
                NavigationLink(destination: BildirimAyarlariView()) {
                    AyarIkonu(iconName: "bell.badge.fill", color: .red)
                    Text(LocalizedStringKey("settings.notifications"))
                }
                .padding(.vertical, 4)
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
        .navigationTitle(currentTitle) // Başlık @State değişkeninden geliyor
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(LocalizedStringKey("common.done")) {
                    dismiss()
                }
            }
        }
        .onAppear(perform: updateTitle)
        .onChange(of: appSettings.languageCode) {
            updateTitle()
        }
    }
    
    // --- DÜZELTİLMİŞ FONKSİYON ---
    private func updateTitle() {
        let key = "settings.title"
        let dilKodu = appSettings.languageCode
        
        // Doğru dil paketini (bundle) buluyoruz.
        guard let path = Bundle.main.path(forResource: dilKodu, ofType: "lproj"),
              let languageBundle = Bundle(path: path) else {
            // Hata durumunda anahtarı olduğu gibi göster.
            self.currentTitle = key
            return
        }
        
        // Metni, telefonun sistem dilinden bağımsız olarak,
        // bizim seçtiğimiz dil paketinden alıyoruz.
        self.currentTitle = languageBundle.localizedString(forKey: key, value: key, table: nil)
    }
}


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


#Preview {
    let settings = AppSettings()
    
    return NavigationStack {
        AyarlarView()
            .environmentObject(settings)
            .environment(\.locale, .init(identifier: settings.languageCode))
    }
}
