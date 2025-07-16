import SwiftUI
import Charts

struct KategoriDetayView: View {
    let rapor: KategoriRaporVerisi
    @EnvironmentObject var appSettings: AppSettings
    @Environment(\.dismiss) private var dismiss
    
    @State private var secilenTab = 0
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Ana bilgiler
                    anaOzetKarti
                    
                    // Tab seçici
                    Picker("Detay Tipi", selection: $secilenTab) {
                        Text("İsimler").tag(0)
                        Text("Günler").tag(1)
                        Text("Saatler").tag(2)
                        Text("Trend").tag(3)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    // İçerik
                    switch secilenTab {
                    case 0:
                        isimlerDetayi
                    case 1:
                        gunlerDetayi
                    case 2:
                        saatlerDetayi
                    case 3:
                        trendDetayi
                    default:
                        EmptyView()
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle(LocalizedStringKey(rapor.kategori.localizationKey ?? rapor.kategori.isim))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kapat") { dismiss() }
                }
            }
        }
    }
    
    @ViewBuilder
    private var anaOzetKarti: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: rapor.kategori.ikonAdi)
                    .font(.largeTitle)
                    .foregroundColor(rapor.kategori.renk)
                    .frame(width: 60, height: 60)
                    .background(rapor.kategori.renk.opacity(0.15))
                    .cornerRadius(12)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Toplam Harcama")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(formatCurrency(
                        amount: rapor.toplamTutar,
                        currencyCode: appSettings.currencyCode,
                        localeIdentifier: appSettings.languageCode
                    ))
                    .font(.title.bold())
                }
                
                Spacer()
            }
            
            HStack(spacing: 20) {
                VStack {
                    Text("\(rapor.islemSayisi)")
                        .font(.title2.bold())
                    Text("İşlem")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                VStack {
                    Text(formatCurrency(
                        amount: rapor.ortalamaTutar,
                        currencyCode: appSettings.currencyCode,
                        localeIdentifier: appSettings.languageCode
                    ))
                    .font(.title3.bold())
                    Text("Ortalama")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                VStack {
                    Text(formatCurrency(
                        amount: rapor.gunlukOrtalama,
                        currencyCode: appSettings.currencyCode,
                        localeIdentifier: appSettings.languageCode
                    ))
                    .font(.title3.bold())
                    Text("Günlük")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private var isimlerDetayi: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("En Sık Kullanılan İşlem İsimleri")
                .font(.headline)
                .padding(.horizontal)
            
            ForEach(rapor.enSikKullanilanIsimler) { isimFrekansi in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(isimFrekansi.isim)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("\(isimFrekansi.frekans) kez kullanıldı")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(formatCurrency(
                            amount: isimFrekansi.toplamTutar,
                            currencyCode: appSettings.currencyCode,
                            localeIdentifier: appSettings.languageCode
                        ))
                        .font(.subheadline.bold())
                        
                        Text("Ort: " + formatCurrency(
                            amount: isimFrekansi.ortalamatutar,
                            currencyCode: appSettings.currencyCode,
                            localeIdentifier: appSettings.languageCode
                        ))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(8)
                .padding(.horizontal)
            }
        }
    }
    
    @ViewBuilder
    private var gunlerDetayi: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Günlere Göre Dağılım")
                .font(.headline)
                .padding(.horizontal)
            
            Chart(rapor.gunlereGoreDagilim) { gun in
                BarMark(
                    x: .value("Gün", gun.gunAdi),
                    y: .value("Tutar", gun.tutar)
                )
                .foregroundStyle(rapor.kategori.renk)
                .cornerRadius(4)
            }
            .frame(height: 200)
            .padding(.horizontal)
            
            ForEach(rapor.gunlereGoreDagilim) { gun in
                HStack {
                    Text(gun.gunAdi)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(formatCurrency(
                            amount: gun.tutar,
                            currencyCode: appSettings.currencyCode,
                            localeIdentifier: appSettings.languageCode
                        ))
                        .fontWeight(.semibold)
                        
                        Text("\(gun.islemSayisi) işlem")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private var saatlerDetayi: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Saatlere Göre Dağılım")
                .font(.headline)
                .padding(.horizontal)
            
            // Radyal saat grafiği
            RadyalSaatGrafigi(
                saatlikDagilim: rapor.saatlereGoreDagilim.map { saatlik in
                    SaatlikDagilimVerisi(
                        saat: saatlik.saat,
                        toplamTutar: saatlik.tutar,
                        islemSayisi: saatlik.islemSayisi,
                        yuzde: 0 // Yüzde hesaplanacak
                    )
                }
            )
            .padding(.horizontal)
        }
    }
    
    @ViewBuilder
    private var trendDetayi: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Aylık Trend")
                .font(.headline)
                .padding(.horizontal)
            
            if !rapor.aylikTrend.isEmpty {
                Chart(rapor.aylikTrend) { nokta in
                    LineMark(
                        x: .value("Ay", nokta.ay),
                        y: .value("Tutar", nokta.tutar)
                    )
                    .foregroundStyle(rapor.kategori.renk)
                    .interpolationMethod(.catmullRom)
                    
                    PointMark(
                        x: .value("Ay", nokta.ay),
                        y: .value("Tutar", nokta.tutar)
                    )
                    .foregroundStyle(rapor.kategori.renk)
                    .symbolSize(100)
                }
                .frame(height: 200)
                .padding(.horizontal)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}
