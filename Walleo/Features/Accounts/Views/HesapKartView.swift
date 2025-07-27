import SwiftUI

struct HesapKartView: View {
    let gosterilecekHesap: GosterilecekHesap
    @EnvironmentObject var appSettings: AppSettings
    var onEdit: () -> Void = {}
    var onDelete: () -> Void = {}
    @State private var showingBalanceInfo = false // YENİ

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: gosterilecekHesap.hesap.ikonAdi).font(.headline).foregroundColor(.white).frame(width: 38, height: 38).background(gosterilecekHesap.hesap.renk).cornerRadius(8)
                Text(gosterilecekHesap.hesap.isim).font(.headline)
                Spacer()
                Menu {
                    Button(action: onEdit) { Label(LocalizedStringKey("common.edit"), systemImage: "pencil") }
                    Button(role: .destructive, action: onDelete) { Label(LocalizedStringKey("common.delete"), systemImage: "trash") }
                } label: {
                    Image(systemName: "ellipsis").font(.callout).foregroundColor(.secondary).frame(width: 40, height: 40).contentShape(Rectangle())
                }
            }
            
            // YENİ: Karmaşık switch ifadesini ayrı bir bileşene taşıdık
            // ve burada sadece o bileşeni çağırıyoruz. Bu, derleyiciyi rahatlatır.
            hesapDetayView
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // --- YENİ EKLENEN BÖLÜM ---
    // Switch ifadesini, kendi başına bir View döndüren bu bileşene taşıyoruz.
    @ViewBuilder
    private var hesapDetayView: some View {
        switch gosterilecekHesap.hesap.detay {
        case .cuzdan:
            cuzdanView()
            
        case .krediKarti(let limit, _, _): // Ofset'i de alıyoruz ama kullanmıyoruz
            krediKartiView(limit: limit)
        
        case .kredi(_, _, _, let taksitSayisi, _, _):
            krediView(toplamTaksit: taksitSayisi)
        }
    }
    // --- YENİ BÖLÜM SONU ---
    
    // Geri kalan yardımcı View'lar (cuzdanView, krediKartiView, krediView) aynı kalıyor.
    @ViewBuilder
    private func cuzdanView() -> some View {
        VStack(alignment: .leading, spacing: 10) {
            
            // 1. Satır: Başlangıç Bakiyesi (aynı kalacak)
            HStack {
                Text(LocalizedStringKey("accounts.card.initial_balance"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(formatCurrency(
                    amount: gosterilecekHesap.hesap.baslangicBakiyesi,
                    currencyCode: appSettings.currencyCode,
                    localeIdentifier: appSettings.languageCode
                ))
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            }
            
            // 2. Satır: Güncel Bakiye - INFO BUTONU EKLENDİ
            HStack {
                // YENİ: Başlık ve info butonu için HStack
                HStack(spacing: 4) {
                    Text(LocalizedStringKey("accounts.card.current_balance"))
                        .font(.headline)
                        .fontWeight(.bold)
                    
                    // YENİ: Info butonu
                    Button(action: {
                        showingBalanceInfo = true
                    }) {
                        Image(systemName: "info.circle")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                Spacer()
                
                Text(formatCurrency(
                    amount: gosterilecekHesap.guncelBakiye,
                    currencyCode: appSettings.currencyCode,
                    localeIdentifier: appSettings.languageCode
                ))
                .font(.title2.bold())
                .foregroundColor(gosterilecekHesap.guncelBakiye < 0 ? .red : .primary)
            }
        }
        // YENİ: Alert ekle
        .alert(
            LocalizedStringKey("accounts.balance_info.title"),
            isPresented: $showingBalanceInfo
        ) {
            Button("common.ok", role: .cancel) { }
        } message: {
            Text(LocalizedStringKey("accounts.balance_info.message"))
        }
    }
    
    @ViewBuilder
    private func krediKartiView(limit: Double) -> some View {
        // Verileri güvenli bir şekilde çekmek için if let yapısını genişletiyoruz.
        if let detay = gosterilecekHesap.krediKartiDetay,
           case .krediKarti(_, let kesimTarihi, _) = gosterilecekHesap.hesap.detay {
            
            VStack(spacing: 12) {
                // --- Bu bölüm aynı kalıyor ---
                let isOverLimit = detay.guncelBorc > limit && limit > 0
                
                // 1. Borcun negatif olmamasını sağla (max(0, ...))
                // 2. Borcun limiti geçmemesini sağla (min(..., limit))
                let progressValue = max(0, min(detay.guncelBorc, limit))
                
                ProgressView(value: progressValue, total: limit > 0 ? limit : 1)
                    .tint(isOverLimit ? .purple : .red)
                
                HStack {
                    VStack(alignment: .leading) {
                        Text(LocalizedStringKey("accounts.card.current_debt"))
                            .font(.caption).foregroundColor(.secondary)
                        Text(formatCurrency(amount: detay.guncelBorc, currencyCode: appSettings.currencyCode, localeIdentifier: appSettings.languageCode))
                            .font(.callout.bold()).foregroundStyle(.red)
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text(LocalizedStringKey("accounts.card.available_limit"))
                            .font(.caption).foregroundColor(.secondary)
                        Text(formatCurrency(amount: detay.kullanilabilirLimit, currencyCode: appSettings.currencyCode, localeIdentifier: appSettings.languageCode))
                            .font(.callout.bold()).foregroundStyle(.green)
                    }
                }
                
                // --- YENİ EKLENEN BÖLÜM ---
                Divider().padding(.top, 4)
                
                VStack(spacing: 6) {
                    // Toplam Limit Satırı
                    HStack {
                        Text(LocalizedStringKey("accounts.card.total_limit"))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(formatCurrency(amount: limit, currencyCode: appSettings.currencyCode, localeIdentifier: appSettings.languageCode))
                            .font(.caption2.bold())
                            .foregroundColor(.secondary)
                    }
                    
                    // Hesap Kesim Tarihi Satırı
                    HStack {
                        Text(LocalizedStringKey("accounts.card.statement_date"))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                        // Yukarıda eklediğimiz yeni yardımcı fonksiyonu burada kullanıyoruz
                        Text(formatNextStatementDate(from: kesimTarihi))
                            .font(.caption2.bold())
                            .foregroundColor(.secondary)
                    }
                }
                // --- YENİ BÖLÜM SONU ---
            }
        }
    }
    
    @ViewBuilder private func krediView(toplamTaksit: Int) -> some View {
        if let detay = gosterilecekHesap.krediDetay {
            VStack(spacing: 12) {
                ProgressView(value: Double(detay.odenenTaksitSayisi), total: Double(toplamTaksit) > 0 ? Double(toplamTaksit) : 1).tint(gosterilecekHesap.hesap.renk)
                HStack {
                    VStack(alignment: .leading) {
                        Text(LocalizedStringKey("accounts.card.paid_installments")).font(.caption).foregroundColor(.secondary)
                        Text("\(detay.odenenTaksitSayisi) / \(toplamTaksit)").font(.callout.bold())
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text(LocalizedStringKey("accounts.add.loan_amount")).font(.caption).foregroundColor(.secondary)
                        Text(formatCurrency(amount: abs(gosterilecekHesap.guncelBakiye), currencyCode: appSettings.currencyCode, localeIdentifier: appSettings.languageCode))
                            .font(.callout.bold()).foregroundStyle(.red)
                    }
                }
            }
        }
    }
    private func formatNextStatementDate(from statementDate: Date) -> String {
        let calendar = Calendar.current
        let today = Date()
        
        // Kayıtlı hesap kesim gününü al (örn: 12)
        let statementDayComponent = calendar.component(.day, from: statementDate)
        
        // Bugünün tarih bileşenlerini al
        var todayComponents = calendar.dateComponents([.year, .month, .day], from: today)
        
        let nextStatementDate: Date
        
        // Eğer bugün, kesim gününü geçmişse, bir sonraki ayın kesim tarihini hedefle
        if todayComponents.day! > statementDayComponent {
            guard let nextMonthDate = calendar.date(byAdding: .month, value: 1, to: today) else {
                return ""
            }
            var nextMonthComponents = calendar.dateComponents([.year, .month], from: nextMonthDate)
            nextMonthComponents.day = statementDayComponent
            nextStatementDate = calendar.date(from: nextMonthComponents) ?? today
        }
        // Eğer bugün, kesim günü veya daha öncesiyse, bu ayın kesim tarihini hedefle
        else {
            var currentMonthComponents = calendar.dateComponents([.year, .month], from: today)
            currentMonthComponents.day = statementDayComponent
            nextStatementDate = calendar.date(from: currentMonthComponents) ?? today
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMMM yyyy" // "12 Ağustos 2025" formatı
        formatter.locale = Locale(identifier: appSettings.languageCode)
        
        return formatter.string(from: nextStatementDate)
    }
}
