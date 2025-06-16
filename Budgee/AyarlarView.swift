import SwiftUI

struct AyarlarView: View {
    @EnvironmentObject var appSettings: AppSettings
    
    var body: some View {
        Form {
            Section("GENEL") {
                HStack {
                    AyarIkonu(iconName: "circle.righthalf.filled", color: .gray)
                    Text("Tema")
                    Spacer()
                    Picker("", selection: $appSettings.colorSchemeValue) {
                        Text("Sistem").tag(0)
                        Text("Açık").tag(1)
                        Text("Koyu").tag(2)
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
                .padding(.vertical, 4)
                
                NavigationLink(destination: KategoriYonetimView()) {
                    AyarIkonu(iconName: "folder.fill", color: .orange)
                    Text("Kategorileri Yönet")
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("Ayarlar")
    }
}

struct AyarIkonu: View {
    let iconName: String
    let color: Color
    
    var body: some View {
        Image(systemName: iconName)
            .font(.title3)
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
