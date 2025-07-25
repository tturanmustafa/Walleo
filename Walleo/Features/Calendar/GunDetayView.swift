import SwiftUI
import SwiftData

// +++ YARDIMCI VIEW (Değişiklik yok) +++
// Günlük Gelir/Gider/Net özetini gösteren kart.
struct GunlukOzetKarti: View {
    @EnvironmentObject var appSettings: AppSettings
    let gelir: Double
    let gider: Double
    let net: Double
    
    // OzetSatiri'nı yeniden kullanmak için buraya da ekliyoruz.
    private struct OzetSatiri: View {
        @EnvironmentObject var appSettings: AppSettings
        let renk: Color
        let baslik: LocalizedStringKey
        let tutar: Double
        
        var body: some View {
            HStack {
                Circle().fill(renk).frame(width: 8, height: 8)
                VStack(alignment: .leading) {
                    Text(baslik)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatCurrency(amount: tutar, currencyCode: appSettings.currencyCode, localeIdentifier: appSettings.languageCode))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                }
                Spacer()
            }
            .contentShape(Rectangle())
        }
    }
    
    var body: some View {
        HStack(spacing: 15) {
            Menu {
                Text(formatCurrency(amount: gelir, currencyCode: appSettings.currencyCode, localeIdentifier: appSettings.languageCode))
            } label: {
                OzetSatiri(renk: .green, baslik: "common.income", tutar: gelir)
            }
            .buttonStyle(.plain)

            Menu {
                Text(formatCurrency(amount: gider, currencyCode: appSettings.currencyCode, localeIdentifier: appSettings.languageCode))
            } label: {
                OzetSatiri(renk: .red, baslik: "common.expense", tutar: gider)
            }
            .buttonStyle(.plain)

            Menu {
                Text(formatCurrency(amount: net, currencyCode: appSettings.currencyCode, localeIdentifier: appSettings.languageCode))
            } label: {
                OzetSatiri(renk: net >= 0 ? .blue : .orange, baslik: "common.net", tutar: net)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding([.horizontal, .bottom])
    }
}


struct GunDetayView: View {
    @EnvironmentObject var appSettings: AppSettings
    @Environment(\.modelContext) private var modelContext
    
    @Query private var islemler: [Islem]
    
    @State private var duzenlenecekIslem: Islem?
    @State private var silinecekTekrarliIslem: Islem?
    @State private var silinecekTekilIslem: Islem?
    @State private var silinecekTaksitliIslem: Islem?
    
    @State private var isDeleting = false
    
    let secilenTarih: Date
    
    // 🔴 YENİ EKLENDİ: Formatlanmış tarih metni için computed property
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: appSettings.languageCode)
        formatter.dateFormat = "d MMMM yyyy, EEEE" // Örn: "25 Ocak 2025, Cumartesi"
        return formatter.string(from: secilenTarih)
    }
    
    private var toplamGelir: Double {
        islemler.filter { $0.tur == .gelir }.reduce(0) { $0 + $1.tutar }
    }
    
    private var toplamGider: Double {
        islemler.filter { $0.tur == .gider }.reduce(0) { $0 + $1.tutar }
    }
    
    private var netAkis: Double {
        toplamGelir - toplamGider
    }
    
    init(secilenTarih: Date) {
        self.secilenTarih = secilenTarih
        
        let calendar = Calendar.current
        let baslangic = calendar.startOfDay(for: secilenTarih)
        let bitis = calendar.date(byAdding: .day, value: 1, to: baslangic)!
        
        let predicate = #Predicate<Islem> { $0.tarih >= baslangic && $0.tarih < bitis }
        _islemler = Query(filter: predicate, sort: \Islem.tarih, order: .reverse)
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) { // Bu spacing: 0 kalabilir, boşluğu padding ile kontrol edeceğiz
                
                // 🔴 YENİ EKLENDİ: Tarih bilgisi header'ı
                Text(formattedDate)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 20)
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray6))
                
                List {
                    ForEach(islemler) { islem in
                        IslemSatirView(
                            islem: islem,
                            onEdit: { duzenlenecekIslem = islem },
                            onDelete: { silmeyiBaslat(islem) }
                        )
                    }
                }
                .listStyle(.insetGrouped)
                .overlay {
                    if islemler.isEmpty && !isDeleting {
                        ContentUnavailableView {
                            Label(LocalizedStringKey("calendar.no_transactions_on_date"), systemImage: "calendar.badge.exclamationmark")
                        }
                    }
                }
                
                if !islemler.isEmpty {
                    // --- DEĞİŞİKLİK BURADA ---
                    // Divider kaldırıldı ve özet kartına üstten biraz boşluk (padding) eklendi.
                    GunlukOzetKarti(
                        gelir: toplamGelir,
                        gider: toplamGider,
                        net: netAkis
                    )
                    .padding(.top, 8) // İki alan arasına boşluk ekler.
                    .environmentObject(appSettings)
                }
            }
            .disabled(isDeleting)
            // 🔴 KALDIRILDI: .navigationTitle(secilenTarih.formatted(date: .long, time: .omitted))
            .sheet(item: $duzenlenecekIslem) { islem in
                IslemEkleView(duzenlenecekIslem: islem)
                    .environmentObject(appSettings)
            }
            .confirmationDialog(
                LocalizedStringKey("alert.recurring_transaction"),
                isPresented: Binding(isPresented: $silinecekTekrarliIslem),
                presenting: silinecekTekrarliIslem
            ) { islem in
                Button("alert.delete_this_only", role: .destructive) {
                    TransactionService.shared.deleteTransaction(islem, in: modelContext)
                }
                Button("alert.delete_series", role: .destructive) {
                    Task {
                        isDeleting = true
                        await TransactionService.shared.deleteSeriesInBackground(tekrarID: islem.tekrarID, from: modelContext.container)
                        isDeleting = false
                    }
                }
                Button("common.cancel", role: .cancel) { }
            }
            .alert(
                LocalizedStringKey("alert.installment.delete_title"),
                isPresented: Binding(isPresented: $silinecekTaksitliIslem),
                presenting: silinecekTaksitliIslem
            ) { islem in
                Button(role: .destructive) {
                    TransactionService.shared.deleteTaksitliIslem(islem, in: modelContext)
                } label: {
                    Text("common.delete")
                }
            } message: { islem in
                Text(String(format: NSLocalizedString("transaction.installment.delete_warning", comment: ""), islem.toplamTaksitSayisi))
            }
            .alert(
                LocalizedStringKey("alert.delete_confirmation.title"),
                isPresented: Binding(isPresented: $silinecekTekilIslem),
                presenting: silinecekTekilIslem
            ) { islem in
                Button(role: .destructive) {
                    TransactionService.shared.deleteTransaction(islem, in: modelContext)
                } label: { Text("common.delete") }
            } message: { islem in
                Text("alert.delete_transaction.message")
            }
            
            if isDeleting {
                ProgressView("Seri Siliniyor...")
                    .padding(25)
                    .background(Material.thick)
                    .cornerRadius(10)
                    .shadow(radius: 5)
            }
        }
    }
    
    private func silmeyiBaslat(_ islem: Islem) {
        if islem.taksitliMi {
            silinecekTaksitliIslem = islem
        } else if islem.tekrar != .tekSeferlik && islem.tekrarID != UUID() {
            silinecekTekrarliIslem = islem
        } else {
            silinecekTekilIslem = islem
        }
    }
}
