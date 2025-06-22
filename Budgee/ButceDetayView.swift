import SwiftUI
import SwiftData

struct ButceDetayView: View {
    @EnvironmentObject var appSettings: AppSettings
    @State private var viewModel: ButceDetayViewModel
    
    // Gruplanmış işlemler için bir sözlük yapısı
    private var gruplanmisIslemler: [Date: [Islem]] {
        Dictionary(grouping: viewModel.donemIslemleri) { islem in
            Calendar.current.startOfDay(for: islem.tarih)
        }
    }
    
    private var siraliGunler: [Date] {
        gruplanmisIslemler.keys.sorted(by: >)
    }

    init(butce: Butce, modelContext: ModelContext) {
        _viewModel = State(initialValue: ButceDetayViewModel(modelContext: modelContext, butce: butce))
    }

    var body: some View {
        List {
            // 1. Bölüm: Bütçe Özet Kartı
            if let gosterilecekButce = viewModel.gosterilecekButce {
                Section {
                    ButceKartView(gosterilecekButce: gosterilecekButce)
                        .environmentObject(appSettings)
                }
            }

            // 2. Bölüm: İşlem Listesi
            if viewModel.donemIslemleri.isEmpty {
                ContentUnavailableView(
                    "Bu Bütçe İçin İşlem Yok",
                    systemImage: "doc.text.magnifyingglass"
                )
            } else {
                // İşlemleri tarihe göre gruplayarak listele
                ForEach(siraliGunler, id: \.self) { gun in
                    Section(header: Text(gun, format: .dateTime.day().month().year())) {
                        ForEach(gruplanmisIslemler[gun] ?? []) { islem in
                            IslemSatirView(islem: islem)
                        }
                    }
                }
            }
        }
        .navigationTitle(viewModel.butce.isim)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            // DÜZELTME: 'async' fonksiyonun başına 'await' eklendi.
            await viewModel.fetchData()
        }
    }
}
