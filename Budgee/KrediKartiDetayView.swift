// Dosya Adı: KrediKartiDetayView.swift

import SwiftUI
import SwiftData

struct KrediKartiDetayView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: KrediKartiDetayViewModel
    
    init(kartHesabi: Hesap) {
        // --- DÜZELTME BURADA ---
        // ModelContainer'a artık tüm modellerimizi tanıtıyoruz.
        let container = try! ModelContainer(for: Hesap.self, Islem.self, Kategori.self)
        // ---
        
        _viewModel = State(initialValue: KrediKartiDetayViewModel(modelContext: container.mainContext, kartHesabi: kartHesabi))
    }

    var body: some View {
        List {
            Section("Son Dönem Harcamaları") {
                if viewModel.donemIslemleri.isEmpty {
                    ContentUnavailableView("Bu Dönem İşlem Yok", systemImage: "creditcard.slash")
                } else {
                    ForEach(viewModel.donemIslemleri) { islem in
                        IslemSatirView(islem: islem)
                    }
                }
            }
        }
        .navigationTitle(viewModel.kartHesabi.isim)
        .task {
            viewModel.modelContext = self.modelContext
            viewModel.islemleriGetir()
        }
    }
}
