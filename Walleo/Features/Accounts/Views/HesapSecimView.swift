import SwiftUI
import SwiftData

struct HesapSecimView: View {
    @Environment(\.dismiss) private var dismiss
    
    let odemeHesaplari: [Hesap]
    let onHesapSecildi: (Hesap) -> Void

    var body: some View {
        NavigationStack {
            List(odemeHesaplari) { hesap in
                Button(action: {
                    onHesapSecildi(hesap)
                    dismiss()
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: hesap.ikonAdi)
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(hesap.renk) // GÜNCELLEME: Arka planı daha canlı hale getirdik.
                            .cornerRadius(8)
                        
                        // --- YENİ GÜNCELLEME BURADA ---
                        // Hesap adı ve türünü dikey olarak hizalamak için VStack kullandık.
                        VStack(alignment: .leading, spacing: 2) {
                            Text(hesap.isim)
                                .foregroundColor(.primary)
                            
                            Text(LocalizedStringKey(subtitle(for: hesap)))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 4) // Satıra biraz boşluk ekledik.
                }
            }
            .navigationTitle(LocalizedStringKey("account_selection.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
            }
        }
    }
    
    // YENİ YARDIMCI FONKSİYON: Hesap türüne göre doğru çeviri anahtarını döndürür.
    private func subtitle(for hesap: Hesap) -> String {
        switch hesap.detay {
        case .cuzdan:
            return "account_type.wallet"
        case .krediKarti:
            return "account_type.credit_card"
        case .kredi:
            // Bu ekranda kredi listelenmeyecek ama her ihtimale karşı ekliyoruz.
            return ""
        }
    }
}
