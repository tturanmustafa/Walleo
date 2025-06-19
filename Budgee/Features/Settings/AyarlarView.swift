// Dosya Adı: AyarlarView.swift (GÜNCELLENMİŞ HALİ)

import SwiftUI

struct AyarlarView: View {
    @EnvironmentObject var appSettings: AppSettings
    @Environment(\.dismiss) var dismiss // EKLENDİ: Ekranı kapatmak için

    var body: some View {
        // Form'un kendisinde bir değişiklik yok.
        Form {
            Section("settings.section_general") {
                // ... mevcut tüm ayar satırları aynı kalıyor ...
                HStack {
                    AyarIkonu(iconName: "circle.righthalf.filled", color: .gray)
                    Text("settings.theme")
                    Spacer()
                    Picker("Tema", selection: $appSettings.colorSchemeValue) {
                        Text("settings.theme_system").tag(0)
                        Text("settings.theme_light").tag(1)
                        Text("settings.theme_dark").tag(2)
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
                .padding(.vertical, 4)
                
                HStack {
                    AyarIkonu(iconName: "globe", color: .blue)
                    Text("settings.language")
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
                    Text("settings.currency")
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
                    Text("settings.manage_categories")
                }
                .padding(.vertical, 4)
            }
            
            Section("settings.section_info") {
                HStack {
                    Text("settings.version")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("settings.title")
        // --- YENİ EKLENEN KOD ---
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(LocalizedStringKey("common.done")) {
                    dismiss()
                }
            }
        }
        // ---
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
    NavigationStack {
        AyarlarView()
            .environmentObject(AppSettings())
            .environment(\.locale, .init(identifier: "tr"))
    }
}
