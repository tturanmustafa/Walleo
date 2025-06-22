// Dosya Adı: GunDetayView.swift

import SwiftUI
import SwiftData

struct GunDetayView: View {
    @EnvironmentObject var appSettings: AppSettings
    @Environment(\.modelContext) private var modelContext
    
    @Query private var islemler: [Islem]
    @State private var duzenlenecekIslem: Islem?
    @State private var silinecekIslem: Islem?
    
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
            if islemler.isEmpty {
                ContentUnavailableView {
                    Label(LocalizedStringKey("calendar.no_transactions_on_date"), systemImage: "calendar.badge.exclamationmark")
                }
            }
        }
        .navigationTitle(secilenTarih.formatted(date: .long, time: .omitted))
        .sheet(item: $duzenlenecekIslem) { islem in
            IslemEkleView(duzenlenecekIslem: islem)
                .environmentObject(appSettings)
        }
        // --- GÜNCELLEME: Akıllı Bildirim Gönderimi ---
        .recurringTransactionAlert(
            for: $silinecekIslem,
            onDeleteSingle: { islem in
                var userInfo: [String: Any]?
                if let hesapID = islem.hesap?.id {
                    userInfo = ["affectedAccountIDs": [hesapID]]
                }
                modelContext.delete(islem)
                NotificationCenter.default.post(name: .transactionsDidChange, object: nil, userInfo: userInfo)
            },
            onDeleteSeries: { islem in
                var userInfo: [String: Any]?
                if let hesapID = islem.hesap?.id {
                    userInfo = ["affectedAccountIDs": [hesapID]]
                }
                let tekrarID = islem.tekrarID
                try? modelContext.delete(model: Islem.self, where: #Predicate { $0.tekrarID == tekrarID })
                NotificationCenter.default.post(name: .transactionsDidChange, object: nil, userInfo: userInfo)
            }
        )
    }
    
    // --- GÜNCELLEME: Akıllı Bildirim Gönderimi ---
    private func silmeyiBaslat(_ islem: Islem) {
        if islem.tekrar != .tekSeferlik && islem.tekrarID != UUID() {
            silinecekIslem = islem
        } else {
            var userInfo: [String: Any]?
            if let hesapID = islem.hesap?.id {
                userInfo = ["affectedAccountIDs": [hesapID]]
            }
            modelContext.delete(islem)
            NotificationCenter.default.post(name: .transactionsDidChange, object: nil, userInfo: userInfo)
        }
    }
}
