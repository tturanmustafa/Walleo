

import SwiftUI
import SwiftData

struct HesaplarArasiTransferView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appSettings: AppSettings
    
    // Veri Sorguları
    @Query private var tumHesaplar: [Hesap]
    
    // State Değişkenleri
    @State private var kaynakHesapID: UUID?
    @State private var hedefHesapID: UUID?
    @State private var tutarString: String = ""
    @State private var isTutarGecersiz = false
    @State private var isTransferring = false
    
    // Hesaplanmış Özellikler
    private var cuzdanlar: [Hesap] {
        tumHesaplar.filter { hesap in
            if case .cuzdan = hesap.detay { return true }
            return false
        }
    }
    
    private var hedefHesaplar: [Hesap] {
        tumHesaplar.filter { hesap in
            // Kaynak hesap seçildiyse onu hariç tut
            if hesap.id == kaynakHesapID { return false }
            // Kredi hesaplarını hariç tut
            if case .kredi = hesap.detay { return false }
            return true
        }
    }
    
    private var kaynakHesap: Hesap? {
        cuzdanlar.first { $0.id == kaynakHesapID }
    }
    
    private var hedefHesap: Hesap? {
        hedefHesaplar.first { $0.id == hedefHesapID }
    }
    
    private var isFormValid: Bool {
        kaynakHesapID != nil &&
        hedefHesapID != nil &&
        !tutarString.isEmpty &&
        !isTutarGecersiz &&
        stringToDouble(tutarString, locale: Locale(identifier: appSettings.languageCode)) > 0
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Kaynak Hesap Seçimi
                    kaynakHesapSection
                    
                    // Transfer Tutarı
                    transferTutariSection
                    
                    // Hedef Hesap Seçimi
                    hedefHesapSection
                }
                .padding()
            }
            .navigationTitle(LocalizedStringKey("transfer.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("common.cancel")) { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("transfer.button")) {
                        transferYap()
                    }
                    .disabled(!isFormValid || isTransferring)
                }
            }
            .disabled(isTransferring)
        }
        .presentationDetents([.height(500)]) // Popup'ı özel yükseklikle ayarla
    }
    
    // MARK: - Alt Bileşenler
    
    @ViewBuilder
    private var kaynakHesapSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(LocalizedStringKey("transfer.source_account"))
                .font(.headline)
                .foregroundColor(.primary)
            
            Menu {
                ForEach(cuzdanlar) { hesap in
                    Button(action: {
                        withAnimation {
                            kaynakHesapID = hesap.id
                            // Eğer aynı hesap hedef olarak seçiliyse, hedefi temizle
                            if hedefHesapID == hesap.id {
                                hedefHesapID = nil
                            }
                        }
                    }) {
                        HStack {
                            Image(systemName: hesap.ikonAdi)
                                .foregroundColor(hesap.renk)
                            Text(hesap.isim)
                            Spacer()
                            Text(LocalizedStringKey("transfer.type.wallet"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } label: {
                HStack {
                    if let hesap = kaynakHesap {
                        Image(systemName: hesap.ikonAdi)
                            .foregroundColor(hesap.renk)
                        Text(hesap.isim)
                    } else {
                        Text(LocalizedStringKey("transfer.select_wallet"))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
            }
            
            // Seçilen Hesap Detayları
            if let hesap = kaynakHesap {
                hesapDetayKarti(hesap: hesap, isKaynak: true)
            }
        }
    }
    
    @ViewBuilder
    private var transferTutariSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.left.arrow.right.circle.fill")
                .font(.title2)
                .foregroundColor(.blue)
            
            VStack(spacing: 4) {                
                FormattedAmountField(
                    "transfer.amount_placeholder",
                    value: $tutarString,
                    isInvalid: $isTutarGecersiz,
                    locale: Locale(identifier: appSettings.languageCode)
                )
                .frame(height: 40) // Sabit yükseklik
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
    
    @ViewBuilder
    private var hedefHesapSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(LocalizedStringKey("transfer.target_account"))
                .font(.headline)
                .foregroundColor(.primary)
            
            Menu {
                ForEach(hedefHesaplar) { hesap in
                    Button(action: {
                        withAnimation {
                            hedefHesapID = hesap.id
                        }
                    }) {
                        HStack {
                            Image(systemName: hesap.ikonAdi)
                                .foregroundColor(hesap.renk)
                            Text(hesap.isim)
                            Spacer()
                            Text(LocalizedStringKey(hesapTipiAnahtari(hesap: hesap)))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } label: {
                HStack {
                    if let hesap = hedefHesap {
                        Image(systemName: hesap.ikonAdi)
                            .foregroundColor(hesap.renk)
                        Text(hesap.isim)
                    } else {
                        Text(LocalizedStringKey("transfer.select_account"))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
            }
            
            // Seçilen Hesap Detayları
            if let hesap = hedefHesap {
                hesapDetayKarti(hesap: hesap, isKaynak: false)
            }
        }
    }
    
    // MARK: - Yardımcı Görünümler
    
    @ViewBuilder
    private func hesapDetayKarti(hesap: Hesap, isKaynak: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            switch hesap.detay {
            case .cuzdan:
                cuzdanDetayView(hesap: hesap)
                
            case .krediKarti(let limit, let kesimTarihi, _):
                krediKartiDetayView(hesap: hesap, limit: limit, kesimTarihi: kesimTarihi)
                
            case .kredi:
                EmptyView() // Kredi hesapları transfer için kullanılamaz
            }
        }
        .padding()
        .background(isKaynak ? Color.blue.opacity(0.1) : Color.green.opacity(0.1))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isKaynak ? Color.blue.opacity(0.3) : Color.green.opacity(0.3), lineWidth: 1)
        )
    }
    
    @ViewBuilder
    private func cuzdanDetayView(hesap: Hesap) -> some View {
        let guncelBakiye = hesapGuncelBakiyesiniHesapla(hesap: hesap)
        
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(LocalizedStringKey("transfer.name"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(hesap.isim)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            
            HStack {
                Text(LocalizedStringKey("transfer.initial_balance"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(formatCurrency(
                    amount: hesap.baslangicBakiyesi,
                    currencyCode: appSettings.currencyCode,
                    localeIdentifier: appSettings.languageCode
                ))
                .font(.caption)
                .fontWeight(.medium)
            }
            
            HStack {
                Text(LocalizedStringKey("transfer.current_balance"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(formatCurrency(
                    amount: guncelBakiye,
                    currencyCode: appSettings.currencyCode,
                    localeIdentifier: appSettings.languageCode
                ))
                .font(.caption.bold())
                .foregroundColor(guncelBakiye < 0 ? .red : .primary)
            }
        }
    }
    
    @ViewBuilder
    private func krediKartiDetayView(hesap: Hesap, limit: Double, kesimTarihi: Date) -> some View {
        let guncelBorc = krediKartiGuncelBorcHesapla(hesap: hesap)
        let kullanilabilirLimit = max(0, limit - guncelBorc)
        
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(LocalizedStringKey("transfer.name"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(hesap.isim)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            
            HStack {
                Text(LocalizedStringKey("transfer.total_limit"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(formatCurrency(
                    amount: limit,
                    currencyCode: appSettings.currencyCode,
                    localeIdentifier: appSettings.languageCode
                ))
                .font(.caption)
                .fontWeight(.medium)
            }
            
            HStack {
                Text(LocalizedStringKey("transfer.available_limit"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(formatCurrency(
                    amount: kullanilabilirLimit,
                    currencyCode: appSettings.currencyCode,
                    localeIdentifier: appSettings.languageCode
                ))
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.green)
            }
            
            HStack {
                Text(LocalizedStringKey("transfer.current_debt"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(formatCurrency(
                    amount: guncelBorc,
                    currencyCode: appSettings.currencyCode,
                    localeIdentifier: appSettings.languageCode
                ))
                .font(.caption.bold())
                .foregroundColor(.red)
            }
            
            HStack {
                Text(LocalizedStringKey("transfer.statement_date"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(kesimTarihi.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .fontWeight(.medium)
            }
        }
    }
    
    // MARK: - Yardımcı Fonksiyonlar
    
    private func hesapTipiAdi(hesap: Hesap) -> String {
        switch hesap.detay {
        case .cuzdan: return "transfer.type.wallet"
        case .krediKarti: return "transfer.type.credit_card"
        case .kredi: return ""
        }
    }
    
    private func hesapTipiAnahtari(hesap: Hesap) -> String {
        switch hesap.detay {
        case .cuzdan: return "transfer.type.wallet"
        case .krediKarti: return "transfer.type.credit_card"
        case .kredi: return ""
        }
    }
    
    private func hesapGuncelBakiyesiniHesapla(hesap: Hesap) -> Double {
        // İşlem bazlı hesaplama
        let islemlerDegisimi = (hesap.islemler ?? []).reduce(0) { toplam, islem in
            toplam + (islem.tur == .gelir ? islem.tutar : -islem.tutar)
        }
        
        // Transfer bazlı hesaplama
        let gelenTransferler = (hesap.gelenTransferler ?? []).reduce(0) { $0 + $1.tutar }
        let gidenTransferler = (hesap.gidenTransferler ?? []).reduce(0) { $0 + $1.tutar }
        
        return hesap.baslangicBakiyesi + islemlerDegisimi + gelenTransferler - gidenTransferler
    }
    
    private func krediKartiGuncelBorcHesapla(hesap: Hesap) -> Double {
        // Initial borç (pozitif değer olarak saklanıyor)
        let initialBorc = abs(hesap.baslangicBakiyesi)
        
        // Harcamalar (gider işlemleri)
        let harcamalar = (hesap.islemler ?? [])
            .filter { $0.tur == .gider }
            .reduce(0) { $0 + $1.tutar }
        
        // Gelen transferler (borcu azaltır)
        let odemeler = (hesap.gelenTransferler ?? []).reduce(0) { $0 + $1.tutar }
        
        // Giden transferler kredi kartından yapılamaz, bu yüzden hesaba katmıyoruz
        
        return initialBorc + harcamalar - odemeler
    }
    
    private func transferYap() {
        isTransferring = true
        
        guard let kaynak = kaynakHesap,
              let hedef = hedefHesap else {
            isTransferring = false
            return
        }
        
        let tutar = stringToDouble(tutarString, locale: Locale(identifier: appSettings.languageCode))
        
        // Transfer nesnesini oluştur
        let transfer = Transfer(
            tutar: tutar,
            tarih: Date(),
            aciklama: "\(kaynak.isim) → \(hedef.isim)",
            kaynakHesap: kaynak,
            hedefHesap: hedef
        )
        
        modelContext.insert(transfer)
        
        do {
            try modelContext.save()
            
            // Hesap değişikliklerini bildirimi gönder
            NotificationCenter.default.post(
                name: .transactionsDidChange,
                object: nil,
                userInfo: ["affectedAccountIDs": [kaynak.id, hedef.id]]
            )
            
            dismiss()
            
        } catch {
            Logger.log("Transfer kaydedilemedi: \(error)", log: Logger.service, type: .error)
            isTransferring = false
        }
    }
}
