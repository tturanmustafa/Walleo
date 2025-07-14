import SwiftUI
import SwiftData

//================================================================
// MARK: - Ana Bütçeler Görünümü (ButcelerView)
//================================================================

struct ButcelerView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appSettings: AppSettings
    
    // ViewModel, tüm hesaplama ve veri çekme mantığını yönetir.
    @State private var viewModel: ButcelerViewModel?

    // Sheet'leri kontrol etmek için kullanılan state'ler.
    @State private var yeniButceEkleGoster = false
    @State private var duzenlenecekButce: Butce?
    @State private var silinecekButce: Butce?

    var body: some View {
        NavigationStack {
            // ViewModel yüklendiğinde ana içeriği göster, yükleniyorsa ProgressView göster.
            Group {
                if let viewModel = viewModel {
                    mainContentView(viewModel: viewModel)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle(LocalizedStringKey("budgets.title"))
            .toolbar {
                toolbarContent()
            }
        }
        // ViewModel'ı ilk açılışta bir kez oluştur ve veriyi çek.
        .task {
            if viewModel == nil {
                viewModel = ButcelerViewModel(modelContext: modelContext)
                await viewModel?.hesaplamalariTetikle()
            }
        }
        // Yeni bütçe eklendiğinde veya bir bütçe düzenlendiğinde listeyi yenile.
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
        // Bütçe silme uyarısı
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
            let dilKodu = appSettings.languageCode
            guard let path = Bundle.main.path(forResource: dilKodu, ofType: "lproj"),
                  let languageBundle = Bundle(path: path) else {
                return Text(butce.isim)
            }
            let formatString = languageBundle.localizedString(forKey: "alert.delete_budget.message_format", value: "", table: nil)
            return Text(String(format: formatString, butce.isim))
        }
    }

    /// Ana içeriği (liste veya boş ekran) oluşturan yardımcı bileşen.
    @ViewBuilder
    private func mainContentView(viewModel: ButcelerViewModel) -> some View {
        if viewModel.gosterilecekButceler.isEmpty {
            ContentUnavailableView(
                LocalizedStringKey("budgets.empty.title"),
                systemImage: "chart.pie.fill",
                description: Text(LocalizedStringKey("budgets.empty.description"))
            )
        } else {
            budgetListView(viewModel: viewModel)
        }
    }

    /// Aylık gruplanmış bütçe listesini oluşturan bileşen.
    private func budgetListView(viewModel: ButcelerViewModel) -> some View {
        List {
            ForEach(viewModel.siraliAylar, id: \.self) { ay in
                Section(header: ayBasligi(for: ay)) {
                    ForEach(viewModel.gruplanmisButceler[ay] ?? []) { gosterilecekButce in
                        ButceKartLinkView(
                            gosterilecekButce: gosterilecekButce,
                            onEdit: { duzenlenecekButce = gosterilecekButce.butce },
                            onDelete: { silinecekButce = gosterilecekButce.butce }
                        )
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    /// Toolbar içeriğini oluşturan fonksiyon.
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
    
    /// Ay başlığını formatlayan yardımcı fonksiyon.
    private func ayBasligi(for date: Date) -> some View {
        Text(monthYearString(from: date, localeIdentifier: appSettings.languageCode))
            .font(.headline)
            .fontWeight(.bold)
            .padding(.vertical, 4)
    }
}

//================================================================
// MARK: - Bütçe Kartı ve Linki (ButceKartLinkView)
//================================================================

/// Her bir bütçe kartını, `NavigationLink`'ini ve durum (geçmiş/aktif) mantığını yöneten alt bileşen.
struct ButceKartLinkView: View {
    let gosterilecekButce: GosterilecekButce
    
    var onEdit: () -> Void
    var onDelete: () -> Void
    
    private var isGecmisDonem: Bool {
        let bugun = Calendar.current.startOfDay(for: Date())
        let butceDonemi = gosterilecekButce.butce.periyot
        let mevcutAyBasi = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: bugun))!
        return butceDonemi < mevcutAyBasi
    }
    
    var body: some View {
        ZStack {
            // ButceKartView, artık linkin arka planı gibi davranıyor.
            ButceKartView(
                gosterilecekButce: gosterilecekButce,
                isDuzenlenebilir: !isGecmisDonem, // ButceKartView'a düzenlenip düzenlenemeyeceğini iletiyoruz.
                onEdit: onEdit,
                onDelete: onDelete
            )
            .opacity(isGecmisDonem ? 0.7 : 1.0)
            .overlay(alignment: .topLeading) {
                 if isGecmisDonem {
                    Text(LocalizedStringKey("budget.list.period_ended"))
                        .font(.caption2.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.gray.opacity(0.7))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .padding([.top, .leading], 4)
                 }
            }
            
            // Asıl gezinmeyi sağlayan NavigationLink'i görünmez yapıyoruz.
            NavigationLink(destination: ButceDetayView(butce: gosterilecekButce.butce)) {
                EmptyView()
            }
            .opacity(0)
        }
        // Karta tıklandığında menünün açılması için
        .contextMenu {
            if !isGecmisDonem {
                Button(action: onEdit) {
                    Label("common.edit", systemImage: "pencil")
                }
            }
            Button(role: .destructive, action: onDelete) {
                Label("common.delete", systemImage: "trash")
            }
        }
        // Listenin kendi satır stillerini tamamen devre dışı bırakıyoruz.
        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }
}

//================================================================
// MARK: - Bütçeler ViewModel (ButcelerViewModel)
//================================================================

extension ButcelerView {
    @MainActor
    @Observable
    class ButcelerViewModel {
        var modelContext: ModelContext
        
        // Arayüzün kullanacağı gruplanmış ve hesaplanmış veri.
        var gruplanmisButceler: [Date: [GosterilecekButce]] = [:]
        var siraliAylar: [Date] = []
        
        // Sadece ana listede görünecek tüm bütçeler
        var gosterilecekButceler: [GosterilecekButce] = []

        init(modelContext: ModelContext) {
            self.modelContext = modelContext
            // Veri değiştiğinde listeyi yenilemek için dinleyici.
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(hesaplamalariTetikle),
                name: .transactionsDidChange,
                object: nil
            )
        }
        
        /// Veri çekme ve hesaplama işlemini başlatan tetikleyici.
        @objc func hesaplamalariTetikle() {
            Task {
                await butceDurumlariniHesapla()
            }
        }

        /// Seçilen bütçeyi veritabanından siler.
        func deleteButce(_ butce: Butce) {
            modelContext.delete(butce)
            Task {
                await hesaplamalariTetikle()
            }
        }
        
        /// Tüm bütçeleri çeker, harcanan tutarlarını hesaplar ve aylara göre gruplar.
        func butceDurumlariniHesapla() async {
            do {
                // 1. Tüm bütçeleri çek.
                let butceDescriptor = FetchDescriptor<Butce>(sortBy: [SortDescriptor(\.periyot, order: .reverse)])
                let tumButceler = try modelContext.fetch(butceDescriptor)
                
                // 2. Harcama hesaplaması için gerekli tüm işlemleri tek seferde çek.
                let giderTuruRawValue = IslemTuru.gider.rawValue
                let tumGiderler = try modelContext.fetch(FetchDescriptor<Islem>(predicate: #Predicate { $0.turRawValue == giderTuruRawValue }))
                
                // 3. Her bütçe için harcanan tutarı hesapla ve GosterilecekButce nesneleri oluştur.
                var yeniGosterilecekler: [GosterilecekButce] = []
                for butce in tumButceler {
                    let butceAraligi = Calendar.current.dateInterval(of: .month, for: butce.periyot)!
                    let kategoriIDleri = Set(butce.kategoriler?.map { $0.id } ?? [])
                    
                    let harcananTutar = tumGiderler.filter { islem in
                        islem.tarih >= butceAraligi.start &&
                        islem.tarih < butceAraligi.end &&
                        kategoriIDleri.contains(islem.kategori?.id ?? UUID())
                    }.reduce(0) { $0 + $1.tutar }
                    
                    yeniGosterilecekler.append(GosterilecekButce(butce: butce, harcananTutar: harcananTutar))
                }
                
                // 4. Hesaplanan veriyi arayüzün kullanacağı şekilde grupla ve sırala.
                self.gosterilecekButceler = yeniGosterilecekler
                self.gruplanmisButceler = Dictionary(grouping: yeniGosterilecekler) {
                    return Calendar.current.startOfDay(for: $0.butce.periyot)
                }
                self.siraliAylar = self.gruplanmisButceler.keys.sorted(by: >)
                
            } catch {
                Logger.log("Bütçe durumları hesaplanırken hata oluştu: \(error.localizedDescription)", log: Logger.data, type: .error)
            }
        }
    }
}
