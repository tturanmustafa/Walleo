import SwiftUI
import SwiftData

struct GunDetayView: View {
    @EnvironmentObject var appSettings: AppSettings
    @Environment(\.modelContext) private var modelContext
    
    @Query private var islemler: [Islem]
    
    @State private var duzenlenecekIslem: Islem?
    @State private var silinecekTekrarliIslem: Islem?
    @State private var silinecekTekilIslem: Islem?
    
    // YENİ: Seri silinirken gösterilecek yükleme durumu
    @State private var isDeleting = false
    
    let secilenTarih: Date
    
    init(secilenTarih: Date) {
        self.secilenTarih = secilenTarih
        
        let calendar = Calendar.current
        let baslangic = calendar.startOfDay(for: secilenTarih)
        let bitis = calendar.date(byAdding: .day, value: 1, to: baslangic)!
        
        let predicate = #Predicate<Islem> { $0.tarih >= baslangic && $0.tarih < bitis }
        _islemler = Query(filter: predicate, sort: \Islem.tarih, order: .reverse)
    }
    
    var body: some View {
        // YENİ: ZStack ile sarmalıyoruz
        ZStack {
            List {
                ForEach(islemler) { islem in
                    IslemSatirView(
                        islem: islem,
                        onEdit: { duzenlenecekIslem = islem },
                        onDelete: { silmeyiBaslat(islem) }
                    )
                }
            }
            .overlay {
                if islemler.isEmpty && !isDeleting {
                    ContentUnavailableView {
                        Label(LocalizedStringKey("calendar.no_transactions_on_date"), systemImage: "calendar.badge.exclamationmark")
                    }
                }
            }
            .disabled(isDeleting) // Silme işlemi sırasında arayüzü pasif yap
            .navigationTitle(secilenTarih.formatted(date: .long, time: .omitted))
            .sheet(item: $duzenlenecekIslem) { islem in
                IslemEkleView(duzenlenecekIslem: islem)
                    .environmentObject(appSettings)
            }
            // GÜNCELLENDİ: Artık .confirmationDialog kullanıyoruz
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
            // GÜNCELLENDİ: Tekil silme alert'i
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
            
            // YENİ: Yükleme göstergesi
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
        if islem.tekrar != .tekSeferlik && islem.tekrarID != UUID() {
            silinecekTekrarliIslem = islem
        } else {
            silinecekTekilIslem = islem
        }
    }
}
