import SwiftUI
import SwiftData

struct TakvimView: View {
    @EnvironmentObject var appSettings: AppSettings
    @State private var viewModel: TakvimViewModel
    
    // --- DEĞİŞİKLİK 1: currentDate artık @State ---
    // Bu görünüm artık kendi tarih durumunu yönetiyor.
    @State private var currentDate = Date()
    
    @State private var secilenGun: Date?
    
    private let sutunlar: [GridItem] = Array(repeating: GridItem(.flexible()), count: 7)
    
    private var weekdaySymbols: [String] {
        var calendar = Calendar.current
        calendar.locale = Locale(identifier: appSettings.languageCode)
        calendar.firstWeekday = 2 // Pazartesi
        var symbols = calendar.shortWeekdaySymbols
        if !symbols.isEmpty {
            let sunday = symbols.removeFirst()
            symbols.append(sunday)
        }
        return symbols
    }
    
    // --- DEĞİŞİKLİK 2: init metodu basitleştirildi ---
    // Artık dışarıdan bir 'currentDate' binding'i almıyor.
    init(modelContext: ModelContext) {
        _viewModel = State(initialValue: TakvimViewModel(modelContext: modelContext))
    }

    var body: some View {
        // --- DEĞİŞİKLİK 3: NavigationStack eklendi ---
        // Bu, başlık çubuğunu (toolbar) eklememizi sağlar.
        NavigationStack {
            ScrollView {
                VStack {
                    // --- DEĞİŞİKLİK 4: MonthNavigatorView eklendi ---
                    // Dashboard'daki ile aynı ay değiştirici bileşeni.
                    MonthNavigatorView(currentDate: $currentDate)
                        .padding(.bottom, 10)

                    HStack {
                        ForEach(weekdaySymbols, id: \.self) { day in
                            Text(day.uppercased())
                                .font(.caption)
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 5)
                    
                    LazyVGrid(columns: sutunlar, spacing: 10) {
                        ForEach(viewModel.calendarDays) { day in
                            Button(action: {
                                if day.isCurrentMonth {
                                    secilenGun = day.date
                                }
                            }) {
                                CalendarDayCell(day: day)
                                    .environmentObject(appSettings)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                    
                    if viewModel.aylikToplamGelir > 0 || viewModel.aylikToplamGider > 0 {
                        AylikOzetKarti(
                            gelir: viewModel.aylikToplamGelir,
                            gider: viewModel.aylikToplamGider,
                            net: viewModel.aylikNetFark
                        )
                        .padding()
                    }
                }
            }
            // --- DEĞİŞİKLİK 5: Navigasyon başlığı eklendi ---
            .navigationTitle("tab.calendar")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $secilenGun) { gun in
                GunDetayView(secilenTarih: gun)
                    .environmentObject(appSettings)
                    .presentationDetents([.medium, .large])
            }
            .onChange(of: currentDate) {
                viewModel.generateCalendar(forDate: currentDate)
            }
            .onAppear {
                viewModel.generateCalendar(forDate: currentDate)
            }
        }
    }
}

