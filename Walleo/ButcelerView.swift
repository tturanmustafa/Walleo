import SwiftUI
import SwiftData

struct ButcelerView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appSettings: AppSettings
    @State private var viewModel: ButcelerView.ButcelerViewModel? // ViewModel'ı View'ın içinde tanımlıyoruz

    @State private var yeniButceEkleGoster = false
    @State private var duzenlenecekButce: Butce?
    @State private var silinecekButce: Butce?

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel = viewModel {
                    // ANA GÖRÜNÜM ARTIK DAHA BASİT
                    mainContentView(viewModel: viewModel)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle(LocalizedStringKey("budgets.title"))
            .toolbar {
                // Toolbar içeriği de ayrı bir fonksiyona taşındı.
                toolbarContent()
            }
        }
        .sheet(isPresented: $yeniButceEkleGoster, onDismiss: {
            Task { await viewModel?.hesaplamalariTetikle() }
        }) {
            ButceEkleDuzenleView()
        }
        .sheet(item: $duzenlenecekButce, onDismiss: {
            Task { await viewModel?.hesaplamalariTetikle() }
        }) { butce in
            ButceEkleDuzenleView(duzenlenecekButce: butce)
        }
        .task {
            if viewModel == nil {
                viewModel = ButcelerViewModel(modelContext: modelContext)
            }
            await viewModel?.hesaplamalariTetikle()
        }
        .alert(
            LocalizedStringKey("alert.delete_confirmation.title"),
            isPresented: Binding(isPresented: $silinecekButce),
            presenting: silinecekButce
        ) { butce in
            Button(role: .destructive) {
                viewModel?.deleteButce(butce)
            } label: {
                Text("common.delete")
            }
        } message: { butce in
            // ... (alert mesajı aynı kalıyor) ...
            let dilKodu = appSettings.languageCode
            guard let path = Bundle.main.path(forResource: dilKodu, ofType: "lproj"),
                  let languageBundle = Bundle(path: path) else {
                return Text(butce.isim) // Fallback
            }
            let formatString = languageBundle.localizedString(forKey: "alert.delete_budget.message_format", value: "", table: nil)
            return Text(String(format: formatString, butce.isim))
        }
    }

    // YENİ: Ana içerik görünümünü oluşturan yardımcı bileşen
    @ViewBuilder
    private func mainContentView(viewModel: ButcelerViewModel) -> some View {
        if viewModel.gosterilecekButceler.isEmpty {
            ContentUnavailableView(
                LocalizedStringKey("budgets.empty.title"),
                systemImage: "chart.pie.fill",
                description: Text(LocalizedStringKey("budgets.empty.description"))
            )
        } else {
            // Liste görünümü de kendi bileşenine ayrıldı
            budgetScrollView(viewModel: viewModel)
        }
    }

    // YENİ: Kaydırılabilir bütçe listesini oluşturan yardımcı bileşen
    private func budgetScrollView(viewModel: ButcelerViewModel) -> some View {
        ScrollView {
            VStack(spacing: 15) {
                ForEach(viewModel.gosterilecekButceler) { gosterilecekButce in
                    // Tek bir kart bile kendi fonksiyonuna ayrıldı
                    budgetCardLink(gosterilecekButce: gosterilecekButce)
                }
            }
            .padding()
        }
    }

    // YENİ: Tek bir bütçe kartı ve onun NavigationLink'ini oluşturan yardımcı fonksiyon
    private func budgetCardLink(gosterilecekButce: GosterilecekButce) -> some View {
        NavigationLink(destination: ButceDetayView(butce: gosterilecekButce.butce)) {
            ButceKartView(
                gosterilecekButce: gosterilecekButce,
                onEdit: { duzenlenecekButce = gosterilecekButce.butce },
                onDelete: { silinecekButce = gosterilecekButce.butce }
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(action: { duzenlenecekButce = gosterilecekButce.butce }) {
                Label("common.edit", systemImage: "pencil")
            }
            Button(role: .destructive, action: { silinecekButce = gosterilecekButce.butce }) {
                Label("common.delete", systemImage: "trash")
            }
        }
    }
    
    // YENİ: Toolbar içeriğini oluşturan yardımcı fonksiyon
    @ToolbarContentBuilder
    private func toolbarContent() -> some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button(action: { yeniButceEkleGoster = true }) {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                    Text(LocalizedStringKey("button.add_budget"))
                }
            }
        }
    }
}

// ViewModel'ı, derleyicinin işini kolaylaştırmak için View'ın içine bir extension olarak taşıdım.
// Bu, dosya sayısını artırmadan mantıksal bir gruplama sağlar.
extension ButcelerView {
    @MainActor
    @Observable
    class ButcelerViewModel {
        var modelContext: ModelContext
        var gosterilecekButceler: [GosterilecekButce] = []
        
        init(modelContext: ModelContext) {
            self.modelContext = modelContext
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(hesaplamalariTetikle),
                name: .transactionsDidChange,
                object: nil
            )
        }
        
        @objc func hesaplamalariTetikle() {
            Task {
                await butceDurumlariniHesapla()
            }
        }

        func deleteButce(_ butce: Butce) {
            modelContext.delete(butce)
            Task {
                await butceDurumlariniHesapla()
            }
        }
        
        func butceDurumlariniHesapla() async {
            let calendar = Calendar.current
            guard let monthInterval = calendar.dateInterval(of: .month, for: Date()) else { return }

            do {
                let butceDescriptor = FetchDescriptor<Butce>(sortBy: [SortDescriptor(\.olusturmaTarihi)])
                let tumButceler = try modelContext.fetch(butceDescriptor)
                
                let giderTuruRawValue = IslemTuru.gider.rawValue
                let genelIslemPredicate = #Predicate<Islem> { islem in
                    islem.tarih >= monthInterval.start &&
                    islem.tarih < monthInterval.end &&
                    islem.turRawValue == giderTuruRawValue
                }
                let tumAylikGiderler = try modelContext.fetch(FetchDescriptor<Islem>(predicate: genelIslemPredicate))
                let kategoriyeGoreIslemler = Dictionary(grouping: tumAylikGiderler) { $0.kategori?.id }
                
                var yeniGosterilecekler: [GosterilecekButce] = []
                
                for butce in tumButceler {
                    var harcananTutar: Double = 0.0
                    
                    if let butceninKategorileri = butce.kategoriler {
                        for kategori in butceninKategorileri {
                            if let islemler = kategoriyeGoreIslemler[kategori.id] {
                                let buKategorininToplami = islemler.reduce(0) { $0 + $1.tutar }
                                harcananTutar += buKategorininToplami
                            }
                        }
                    }
                    
                    yeniGosterilecekler.append(GosterilecekButce(butce: butce, harcananTutar: harcananTutar))
                }
                
                self.gosterilecekButceler = yeniGosterilecekler
                
            } catch {
                Logger.log("Bütçe durumları hesaplanırken hata oluştu: \(error.localizedDescription)", log: Logger.data, type: .error)
            }
        }
    }
}
