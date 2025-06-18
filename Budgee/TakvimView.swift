import SwiftUI
import SwiftData

struct TakvimView: View {
    @EnvironmentObject var appSettings: AppSettings
    @State private var viewModel: TakvimViewModel
    
    @State private var secilenGun: Date?
    
    private let sutunlar: [GridItem] = Array(repeating: GridItem(.flexible()), count: 7)
    
    private var weekdaySymbols: [String] {
        var calendar = Calendar.current
        calendar.locale = Locale(identifier: appSettings.languageCode)
        calendar.firstWeekday = 2 // Pazartesi haftanın ilk günü

        var symbols = calendar.shortWeekdaySymbols
        if !symbols.isEmpty {
            let sunday = symbols.removeFirst()
            symbols.append(sunday)
        }
        return symbols
    }
    
    init(modelContext: ModelContext) {
        _viewModel = State(initialValue: TakvimViewModel(modelContext: modelContext))
    }

    var body: some View {
        VStack {
            MonthNavigatorView(currentDate: $viewModel.currentDate)
                .environmentObject(appSettings)
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
            
            Spacer()
        }
        .navigationTitle("tab.calendar")
        .sheet(item: $secilenGun, onDismiss: { viewModel.generateCalendar() }) { gun in
            GunDetayView(secilenTarih: gun)
                .environmentObject(appSettings)
                .presentationDetents([.medium, .large])
        }
    }
}
