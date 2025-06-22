import SwiftUI
import SwiftData

struct TakvimView: View {
    @EnvironmentObject var appSettings: AppSettings
    @State private var viewModel: TakvimViewModel
    
    // GÜNCELLEME: Artık tarihi bir Binding olarak dışarıdan alacak.
    @Binding var currentDate: Date
    
    @State private var secilenGun: Date?
    
    private let sutunlar: [GridItem] = Array(repeating: GridItem(.flexible()), count: 7)
    
    private var weekdaySymbols: [String] {
        var calendar = Calendar.current
        calendar.locale = Locale(identifier: appSettings.languageCode)
        calendar.firstWeekday = 2
        var symbols = calendar.shortWeekdaySymbols
        if !symbols.isEmpty {
            let sunday = symbols.removeFirst()
            symbols.append(sunday)
        }
        return symbols
    }
    
    // GÜNCELLEME: init metodu artık bir Binding alıyor.
    init(modelContext: ModelContext, currentDate: Binding<Date>) {
        _viewModel = State(initialValue: TakvimViewModel(modelContext: modelContext))
        _currentDate = currentDate
    }

    var body: some View {
        VStack {
            // MonthNavigatorView buradan kaldırıldı.
            
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
            
            Spacer()
        }
        .sheet(item: $secilenGun) { gun in
            GunDetayView(secilenTarih: gun)
                .environmentObject(appSettings)
                .presentationDetents([.medium, .large])
        }
        // GÜNCELLEME: Dışarıdan gelen tarih değiştiğinde takvimi yeniden oluştur.
        .onChange(of: currentDate) {
            viewModel.generateCalendar(forDate: currentDate)
        }
        // Ekran ilk açıldığında da takvimin doğru ay için oluştuğundan emin ol.
        .onAppear {
            viewModel.generateCalendar(forDate: currentDate)
        }
    }
}
