import SwiftUI

struct KategoriKarsilastirmaKarti: View {
    let karsilastirma: KategoriKarsilastirma
    @EnvironmentObject var appSettings: AppSettings
    
    private var siralamaIcon: String {
        if karsilastirma.oncekiSiralama == -1 {
            return "arrow.up.circle.fill"
        } else if karsilastirma.siralama < karsilastirma.oncekiSiralama {
            return "arrow.up.circle.fill"
        } else if karsilastirma.siralama > karsilastirma.oncekiSiralama {
            return "arrow.down.circle.fill"
        } else {
            return "equal.circle.fill"
        }
    }
    
    private var siralamaColor: Color {
        if karsilastirma.oncekiSiralama == -1 {
            return .green
        } else if karsilastirma.siralama < karsilastirma.oncekiSiralama {
            return .green
        } else if karsilastirma.siralama > karsilastirma.oncekiSiralama {
            return .red
        } else {
            return .orange
        }
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Sıralama göstergesi
            VStack {
                Text("#\(karsilastirma.siralama)")
                    .font(.title.bold())
                
                Image(systemName: siralamaIcon)
                    .foregroundColor(siralamaColor)
                    .font(.caption)
            }
            .frame(width: 50)
            
            // Kategori bilgisi
            HStack {
                Image(systemName: karsilastirma.kategori.ikonAdi)
                    .font(.title3)
                    .foregroundColor(karsilastirma.kategori.renk)
                    .frame(width: 35, height: 35)
                    .background(karsilastirma.kategori.renk.opacity(0.15))
                    .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(LocalizedStringKey(karsilastirma.kategori.localizationKey ?? karsilastirma.kategori.isim))
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    HStack(spacing: 8) {
                        Text(formatCurrency(
                            amount: karsilastirma.mevcutDonemTutar,
                            currencyCode: appSettings.currencyCode,
                            localeIdentifier: appSettings.languageCode
                        ))
                        .font(.caption)
                        .fontWeight(.semibold)
                        
                        if karsilastirma.degisimYuzdesi != 0 {
                            Text(String(format: "%+.1f%%", karsilastirma.degisimYuzdesi))
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(karsilastirma.degisimYuzdesi > 0 ? .red : .green)
                        }
                    }
                }
                
                Spacer()
                
                // Önceki dönem bilgisi
                VStack(alignment: .trailing, spacing: 4) {
                    Text("reports.category.previous")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text(formatCurrency(
                        amount: karsilastirma.oncekiDonemTutar,
                        currencyCode: appSettings.currencyCode,
                        localeIdentifier: appSettings.languageCode
                    ))
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }
}
