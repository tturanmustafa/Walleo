import SwiftUI
import SwiftData

struct TumIslemlerView: View {
    // DOĞRU KULLANIM: @Observable bir sınıf için @State kullanılır.
    @State private var viewModel: TumIslemlerViewModel
    
    // Düzenleme ve Silme için state'ler
    @State private var filtreEkraniGosteriliyor = false
    @State private var duzenlenecekIslem: Islem?
    @State private var duzenlemeEkraniGosteriliyor = false
    @State private var silinecekIslem: Islem?
    
    // init metodu, ViewModel'i oluşturmak için dışarıdan context alır.
    init(modelContext: ModelContext) {
        // @State için ilk değer ataması bu şekilde yapılır.
        _viewModel = State(initialValue: TumIslemlerViewModel(modelContext: modelContext))
    }
    
    var body: some View {
        // Artık guard let, AnyView gibi karmaşık yapılara gerek yok.
        // viewModel her zaman dolu ve kullanıma hazır.
        List {
            ForEach(viewModel.islemler) { islem in
                IslemSatirView(
                    islem: islem,
                    onEdit: {
                        duzenlenecekIslem = islem
                        duzenlemeEkraniGosteriliyor = true
                    },
                    onDelete: {
                        silmeyiBaslat(islem)
                    }
                )
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        silmeyiBaslat(islem)
                    } label: { Label("Sil", systemImage: "trash") }
                    
                    Button {
                        duzenlenecekIslem = islem
                        duzenlemeEkraniGosteriliyor = true
                    } label: { Label("Düzenle", systemImage: "pencil") }
                    .tint(.blue)
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("Tüm İşlemler")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Filtrele") {
                    filtreEkraniGosteriliyor = true
                }
            }
        }
        .sheet(isPresented: $filtreEkraniGosteriliyor) {
            FiltreAyarView(ayarlar: $viewModel.filtreAyarlari)
        }
        .sheet(isPresented: $duzenlemeEkraniGosteriliyor, onDismiss: {
            viewModel.fetchData()
        }) {
            IslemEkleView(duzenlenecekIslem: duzenlenecekIslem)
        }
        .overlay {
            if viewModel.islemler.isEmpty {
                ContentUnavailableView("İşlem Bulunamadı", systemImage: "magnifyingglass", description: Text("Filtre kriterlerinizi değiştirmeyi deneyin."))
            }
        }
        .confirmationDialog("Bu tekrarlayan bir işlemdir.", isPresented: .constant(silinecekIslem != nil), titleVisibility: .visible) {
            Button("Sadece Bu İşlemi Sil", role: .destructive) {
                if let islem = silinecekIslem { viewModel.deleteIslem(islem) }
                silinecekIslem = nil
            }
            Button("Tüm Seriyi Sil", role: .destructive) {
                if let islem = silinecekIslem { viewModel.deleteSeri(islem) }
                silinecekIslem = nil
            }
            Button("İptal", role: .cancel) {
                silinecekIslem = nil
            }
        }
        .onAppear {
            // TumIslemlerViewModel'in init'i zaten veri çektiği için
            // burada tekrar çağırmaya gerek yok, ama kalsa da zararı olmaz.
            // En temiz haliyle, ViewModel'in kendi içinde bu işi halletmesi daha iyidir.
        }
    }
    
    private func silmeyiBaslat(_ islem: Islem) {
        if islem.tekrar != .tekSeferlik && islem.tekrarID != UUID() {
            silinecekIslem = islem
        } else {
            viewModel.deleteIslem(islem)
        }
    }
}
