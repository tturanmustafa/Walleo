import SwiftUI
import Charts

struct RadyalSaatGrafigi: View {
    let saatlikDagilim: [SaatlikDagilimVerisi]
    @EnvironmentObject var appSettings: AppSettings
    
    @State private var secilenSaat: Int?
    @State private var animasyonTamamlandi = false
    
    private var enYogunSaatler: [Int] {
        saatlikDagilim
            .sorted { $0.toplamTutar > $1.toplamTutar }
            .prefix(3)
            .map { $0.saat }
    }
    
    var body: some View {
        // Dil değişimlerinde güncellenecek metinleri burada oluşturuyoruz.
        let dilKodu = appSettings.languageCode
        let languageBundle: Bundle = {
            if let path = Bundle.main.path(forResource: dilKodu, ofType: "lproj"), let bundle = Bundle(path: path) {
                return bundle
            }
            return .main
        }()
        
        let seciliIslemSayisiMetni: String? = {
            if let saat = secilenSaat, let veri = saatlikDagilim.first(where: { $0.saat == saat }) {
                let formatString = languageBundle.localizedString(forKey: "reports.transaction_count", value: "", table: nil)
                return String(format: formatString, veri.islemSayisi)
            }
            return nil
        }()
        
        let enYogunSaatlerMetni: String? = {
            if !enYogunSaatler.isEmpty {
                let formatString = languageBundle.localizedString(forKey: "reports.heatmap.busiest_hours", value: "", table: nil)
                let saatlerString = enYogunSaatler.map { "\($0):00" }.joined(separator: ", ")
                return String(format: formatString, saatlerString)
            }
            return nil
        }()

        return VStack(spacing: 12) {
            HStack {
                Text("reports.heatmap.hourly_distribution")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                if let saat = secilenSaat,
                   let veri = saatlikDagilim.first(where: { $0.saat == saat }),
                   let metin = seciliIslemSayisiMetni {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(saat):00-\((saat + 1) % 24):00")
                            .font(.caption)
                            .fontWeight(.medium)
                        Text(formatCurrency(
                            amount: veri.toplamTutar,
                            currencyCode: appSettings.currencyCode,
                            localeIdentifier: appSettings.languageCode
                        ))
                        .font(.subheadline.bold())
                        .foregroundColor(.accentColor)
                        Text(metin) // <--- Düzeltilmiş metin kullanılıyor
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            
            ZStack {
                // Arka plan çemberleri
                ForEach([0.25, 0.5, 0.75, 1.0], id: \.self) { radius in
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        .frame(width: 160 * radius, height: 160 * radius)
                }
                
                // Saat işaretleri
                ForEach(0..<24, id: \.self) { hour in
                    SaatIsareti(saat: hour)
                }
                
                // Radyal barlar
                ForEach(saatlikDagilim) { veri in
                    RadyalBar(
                        veri: veri,
                        maksimumDeger: saatlikDagilim.map { $0.toplamTutar }.max() ?? 1,
                        isHighlighted: enYogunSaatler.contains(veri.saat),
                        isSelected: secilenSaat == veri.saat,
                        animasyonTamamlandi: animasyonTamamlandi
                    )
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3)) {
                            secilenSaat = secilenSaat == veri.saat ? nil : veri.saat
                        }
                    }
                }
                
                // Merkez bilgi
                VStack(spacing: 4) {
                    Image(systemName: "clock.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text(LocalizedStringKey("reports.heatmap.24_hours"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(width: 70)
                .opacity(secilenSaat == nil ? 1 : 0.5)
            }
            .frame(width: 180, height: 180)
            .onAppear {
                withAnimation(.easeOut(duration: 1.0)) {
                    animasyonTamamlandi = true
                }
            }
            
            // En yoğun saatler
            if let metin = enYogunSaatlerMetni {
                HStack(spacing: 8) {
                    Image(systemName: "flame.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Text(metin) // <--- Düzeltilmiş metin kullanılıyor
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
}

// Saat işareti (Değişiklik yok)
struct SaatIsareti: View {
    let saat: Int
    
    private var angle: Double {
        Double(saat) * 15 - 90
    }
    
    private var isMainHour: Bool {
        saat % 6 == 0
    }
    
    var body: some View {
        Text(isMainHour ? "\(saat)" : "")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .rotationEffect(.degrees(-angle))
            .offset(x: 95 * cos(angle * .pi / 180),
                   y: 95 * sin(angle * .pi / 180))
    }
}

// Radyal bar (Değişiklik yok)
struct RadyalBar: View {
    let veri: SaatlikDagilimVerisi
    let maksimumDeger: Double
    let isHighlighted: Bool
    let isSelected: Bool
    let animasyonTamamlandi: Bool
    
    private var normalizedHeight: Double {
        guard maksimumDeger > 0 else { return 0 }
        return (veri.toplamTutar / maksimumDeger) * 60
    }
    
    private var angle: Double {
        Double(veri.saat) * 15 - 90
    }
    
    private var barColor: Color {
        if isSelected {
            return .accentColor
        } else if isHighlighted {
            return .orange
        } else if veri.toplamTutar == 0 {
            return .gray.opacity(0.3)
        } else {
            return .blue
        }
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(barColor)
            .frame(width: 8, height: animasyonTamamlandi ? normalizedHeight : 0)
            .offset(y: -normalizedHeight / 2 - 40)
            .rotationEffect(.degrees(angle))
            .scaleEffect(isSelected ? 1.2 : 1.0)
            .animation(.spring(response: 0.3), value: isSelected)
    }
}
