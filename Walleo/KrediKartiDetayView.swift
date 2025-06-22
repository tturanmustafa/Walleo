// Dosya Adı: KrediKartiDetayView.swift (GÜNCEL HALİ)

import SwiftUI
import SwiftData

struct KrediKartiDetayView: View {
    @State private var viewModel: KrediKartiDetayViewModel
    
    // GÜNCEL VE GÜVENLİ INIT:
    // Artık 'modelContext'i parametre olarak alıyor, kendisi oluşturmuyor.
    init(kartHesabi: Hesap, modelContext: ModelContext) {
        _viewModel = State(initialValue: KrediKartiDetayViewModel(modelContext: modelContext, kartHesabi: kartHesabi))
    }

    var body: some View {
        List {
            // --- DÜZELTME BURADA ---
            Section(LocalizedStringKey("credit_card_details.recent_expenses")) {
                if viewModel.donemIslemleri.isEmpty {
                    ContentUnavailableView(
                        LocalizedStringKey("credit_card_details.no_transactions"),
                        systemImage: "creditcard.slash"
                    )
                } else {
                    ForEach(viewModel.donemIslemleri) { islem in
                        IslemSatirView(islem: islem)
                    }
                }
            }
        }
        .navigationTitle(viewModel.kartHesabi.isim)
        .task {
            // Context atamasına gerek kalmadı, sadece veri çekme işlemi yapılıyor.
            viewModel.islemleriGetir()
        }
    }
}
