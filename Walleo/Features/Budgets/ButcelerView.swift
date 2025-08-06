import SwiftUI
import SwiftData

//================================================================
// MARK: - Ana Bütçeler Görünümü (ButcelerView)
//================================================================

struct ButcelerView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appSettings: AppSettings
    @EnvironmentObject var entitlementManager: EntitlementManager
    
    // ViewModel, tüm hesaplama ve veri çekme mantığını yönetir.
    @State private var viewModel: ButcelerViewModel?

    // Sheet'leri kontrol etmek için kullanılan state'ler.
    @State private var yeniButceEkleGoster = false
    @State private var duzenlenecekButce: Butce?
    @State private var silinecekButce: Butce?
    @State private var showPremiumLimit = false
    @State private var showPaywall = false

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
                viewModel?.hesaplamalariTetikle()
            }
        }
        // Yeni bütçe eklendiğinde veya bir bütçe düzenlendiğinde listeyi yenile.
        .sheet(isPresented: $yeniButceEkleGoster, onDismiss: {
            viewModel?.hesaplamalariTetikle()
        }) {
            ButceEkleDuzenleView()
        }
        .sheet(item: $duzenlenecekButce, onDismiss: {
            viewModel?.hesaplamalariTetikle()
        }) { butce in
            ButceEkleDuzenleView(duzenlenecekButce: butce)
        }
        // Premium limit popup
        .sheet(isPresented: $showPremiumLimit) {
            PremiumLimitPopup(
                isPresented: $showPremiumLimit,
                limitTuru: .butce,
                onContinue: {
                    showPaywall = true
                }
            )
        }
        // Paywall
        .sheet(isPresented: $showPaywall) {
            PaywallView()
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
            Text(getDeleteMessage(for: butce))
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
            Button(action: {
                kontrolEtVeButceEkle()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                    Text(LocalizedStringKey("button.add_budget"))
                }
            }
        }
    }
    
    /// Premium limit kontrolü yapan fonksiyon
    private func kontrolEtVeButceEkle() {
        // Premium kullanıcılar sınırsız bütçe ekleyebilir
        if entitlementManager.hasPremiumAccess {
            yeniButceEkleGoster = true
            return
        }
        
        // Free kullanıcılar için aktif bütçe sayısını kontrol et
        let buAy = Calendar.current.startOfDay(for: Date())
        guard let ayBaslangici = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: buAy)) else {
            yeniButceEkleGoster = true
            return
        }
        
        // Bu aya ait bütçe sayısını kontrol et
        let aktifButceSayisi = viewModel?.gosterilecekButceler.filter { butce in
            let butceAyBaslangici = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: butce.butce.periyot)) ?? Date()
            return butceAyBaslangici == ayBaslangici
        }.count ?? 0
        
        if aktifButceSayisi >= 1 {
            showPremiumLimit = true
        } else {
            yeniButceEkleGoster = true
        }
    }
    
    /// Ay başlığını formatlayan yardımcı fonksiyon.
    private func ayBasligi(for date: Date) -> some View {
        Text(monthYearString(from: date, localeIdentifier: appSettings.languageCode))
            .font(.headline)
            .fontWeight(.bold)
            .padding(.vertical, 4)
    }
    
    /// Silme mesajını oluşturan yardımcı fonksiyon
    private func getDeleteMessage(for butce: Butce) -> String {
        let dilKodu = appSettings.languageCode
        guard let path = Bundle.main.path(forResource: dilKodu, ofType: "lproj"),
              let languageBundle = Bundle(path: path) else {
            return butce.isim
        }
        let formatString = languageBundle.localizedString(forKey: "alert.delete_budget.message_format", value: "", table: nil)
        return String(format: formatString, butce.isim)
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
        
        var gruplanmisButceler: [Date: [GosterilecekButce]] = [:]
        var siraliAylar: [Date] = []
        var gosterilecekButceler: [GosterilecekButce] = []

        // MARK: - Init & Notification
        
        init(modelContext: ModelContext) {
            self.modelContext = modelContext
            // Bildirim geldiğinde artık "akıllı" fonksiyonu çağırıyoruz.
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleDataChange),
                name: .transactionsDidChange,
                object: nil
            )
        }
        
        /// Gelen bildirimin içeriğini kontrol eder ve duruma göre hedefli veya genel güncelleme yapar.
        @objc private func handleDataChange(notification: Notification) {
            if let payload = notification.userInfo?["payload"] as? TransactionChangePayload,
               let categoryID = payload.affectedCategoryIDs.first {
                // "Akıllı" Yol: Sadece ilgili kategorinin bütçesini güncelle.
                Logger.log("Hedefli bütçe güncellemesi tetiklendi. Kategori ID: \(categoryID)", log: Logger.service)
                Task {
                    await updateTargetedBudgets(for: categoryID)
                }
            } else {
                // "Güvenli" Yol: Her şeyi yeniden hesapla.
                Logger.log("Genel bütçe güncellemesi tetiklendi.", log: Logger.service)
                Task {
                    await updateAllBudgets()
                }
            }
        }
        
        // MARK: - Ana Fonksiyonlar
        
        /// Sadece görünüm ilk açıldığında veya genel bir yenileme gerektiğinde kullanılır.
        func hesaplamalariTetikle() {
            Task {
                await updateAllBudgets()
            }
        }

        func deleteButce(_ butce: Butce) {
            modelContext.delete(butce)
            hesaplamalariTetikle() // Silme sonrası her zaman tam yenileme yapılır.
        }
        
        // MARK: - Güncelleme Stratejileri
        
        /// "Hızlı Yol": Sadece belirli bir kategoriyi içeren bütçelerin harcamalarını yeniden hesaplar.
        private func updateTargetedBudgets(for categoryID: UUID) async {
            await MainActor.run {
                // 1. Sadece etkilenen bütçeleri mevcut listemizden bul.
                let etkilenenButceIDleri = gosterilecekButceler
                    .filter { $0.butce.kategoriler?.contains(where: { $0.id == categoryID }) ?? false }
                    .map { $0.id }
                
                guard !etkilenenButceIDleri.isEmpty else { return }
                
                // 2. Verimlilik için o ayın tüm giderlerini sadece bir kez veritabanından çek.
                do {
                    let butceAraligi = Calendar.current.dateInterval(of: .month, for: Date())!
                    let giderTuruRawValue = IslemTuru.gider.rawValue
                    let descriptor = FetchDescriptor<Islem>(predicate: #Predicate { $0.turRawValue == giderTuruRawValue && $0.tarih >= butceAraligi.start && $0.tarih < butceAraligi.end })
                    let tumAylikGiderler = try modelContext.fetch(descriptor)
                    
                    // 3. Ana listedeki etkilenen bütçeleri bul ve harcamalarını güncelle.
                    for i in 0..<gosterilecekButceler.count {
                        if etkilenenButceIDleri.contains(gosterilecekButceler[i].id) {
                            gosterilecekButceler[i].harcananTutar = calculateSpending(for: gosterilecekButceler[i].butce, using: tumAylikGiderler)
                        }
                    }
                    
                    // 4. Listeyi yeniden grupla ve sırala (veritabanı okuması olmadan).
                    regroupAndSort()
                    
                } catch {
                     Logger.log("Hedefli bütçe güncellemesi sırasında hata: \(error.localizedDescription)", log: Logger.data, type: .error)
                }
            }
        }
        
        /// "Güvenli Yol": Tüm bütçelerin harcamalarını en baştan, veritabanından okuyarak hesaplar.
        private func updateAllBudgets() async {
            await MainActor.run {
                do {
                    let butceDescriptor = FetchDescriptor<Butce>(sortBy: [SortDescriptor(\.periyot, order: .reverse)])
                    let tumButceler = try modelContext.fetch(butceDescriptor)
                    
                    let giderTuruRawValue = IslemTuru.gider.rawValue
                    let descriptor = FetchDescriptor<Islem>(predicate: #Predicate { $0.turRawValue == giderTuruRawValue })
                    let tumGiderler = try modelContext.fetch(descriptor)
                    
                    var yeniGosterilecekler: [GosterilecekButce] = []
                    for butce in tumButceler {
                        let butceAraligi = Calendar.current.dateInterval(of: .month, for: butce.periyot)!
                        let butceGiderleri = tumGiderler.filter { $0.tarih >= butceAraligi.start && $0.tarih < butceAraligi.end }
                        let harcanan = calculateSpending(for: butce, using: butceGiderleri)
                        yeniGosterilecekler.append(GosterilecekButce(butce: butce, harcananTutar: harcanan))
                    }
                    
                    self.gosterilecekButceler = yeniGosterilecekler
                    regroupAndSort()
                    
                } catch {
                    Logger.log("Genel bütçe güncellemesi sırasında hata: \(error.localizedDescription)", log: Logger.data, type: .error)
                }
            }
        }
        
        // MARK: - Yardımcı Fonksiyonlar
        
        /// Tek bir bütçenin harcamasını, önceden çekilmiş işlem listesini kullanarak hesaplar.
        private func calculateSpending(for budget: Butce, using transactions: [Islem]) -> Double {
            let kategoriIDleri = Set(budget.kategoriler?.map { $0.id } ?? [])
            guard !kategoriIDleri.isEmpty else { return 0.0 }
            
            let harcananTutar = transactions.filter { islem in
                guard let kategoriID = islem.kategori?.id else { return false }
                return kategoriIDleri.contains(kategoriID)
            }.reduce(0) { $0 + $1.tutar }
            
            return harcananTutar
        }
        
        /// Mevcut `gosterilecekButceler` listesini aylara göre gruplar ve sıralar.
        private func regroupAndSort() {
            self.gruplanmisButceler = Dictionary(grouping: gosterilecekButceler) { Calendar.current.startOfDay(for: $0.butce.periyot) }
            self.siraliAylar = self.gruplanmisButceler.keys.sorted(by: >)
        }
    }
}
