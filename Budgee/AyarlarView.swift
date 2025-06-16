import SwiftUI

struct AyarlarView: View {
    @EnvironmentObject var appSettings: AppSettings
    
    var body: some View {
        Form {
            Section("settings.section_general") { // DEĞİŞTİ
                HStack {
                    AyarIkonu(iconName: "circle.righthalf.filled", color: .gray)
                    Text("settings.theme") // DEĞİŞTİ
                    Spacer()
                    Picker("Tema", selection: $appSettings.colorSchemeValue) {
                        Text("settings.theme_system").tag(0) // DEĞİŞTİ
                        Text("settings.theme_light").tag(1) // DEĞİŞTİ
                        Text("settings.theme_dark").tag(2) // DEĞİŞTİ
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
                .padding(.vertical, 4)
                
                HStack {
                    AyarIkonu(iconName: "globe", color: .blue)
                    Text("settings.language") // DEĞİŞTİ
                    Spacer()
                    Picker("Dil", selection: $appSettings.languageCode) {
                        Text("Türkçe").tag("tr")
                        Text("English").tag("en")
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
                .padding(.vertical, 4)
                
                NavigationLink(destination: KategoriYonetimView()) {
                    AyarIkonu(iconName: "folder.fill", color: .orange)
                    Text("settings.manage_categories") // DEĞİŞTİ
                }
                .padding(.vertical, 4)
            }
            
            Section("settings.section_info") { // DEĞİŞTİ
                HStack {
                    Text("settings.version") // DEĞİŞTİ
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("settings.title") // DEĞİŞTİ
    }
}

struct AyarIkonu: View {
    let iconName: String
    let color: Color
    
    var body: some View {
        Image(systemName: iconName)
            .font(.callout) // İkonları biraz küçülttüm
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
    }
}
