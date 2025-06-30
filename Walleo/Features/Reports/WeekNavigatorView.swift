import SwiftUI

struct WeekNavigatorView: View {
    @EnvironmentObject var appSettings: AppSettings
    @Binding var currentDate: Date
    
    // GÜNCELLEME: Sheet'in açılıp kapanmasını kontrol edecek state
    @State private var haftaSeciciGosteriliyor = false

    var body: some View {
        HStack {
            Button(action: { changeWeek(by: -1) }) { Image(systemName: "chevron.left") }
            Spacer()
            
            // GÜNCELLEME: Metin artık tıklanabilir
            Text(weekRangeString(from: currentDate, localeIdentifier: appSettings.languageCode))
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .onTapGesture {
                    haftaSeciciGosteriliyor = true
                }
            
            Spacer()
            Button(action: { changeWeek(by: 1) }) { Image(systemName: "chevron.right") }
        }
        .font(.title3)
        .foregroundColor(.secondary)
        .padding(.horizontal, 30)
        .padding(.top)
        // GÜNCELLEME: Sheet'i açan modifier
        .sheet(isPresented: $haftaSeciciGosteriliyor) {
            // GÜNCELLEME: Yüksekliği sabit bir değer yerine, iOS'in belirlediği
            // standart orta ve büyük boyutta olacak şekilde esnek hale getirdik.
            HaftaSeciciView(currentDate: $currentDate)
                .presentationDetents([.medium, .large])
        }
    }
    
    private func changeWeek(by value: Int) {
        if let newDate = Calendar.current.date(byAdding: .weekOfYear, value: value, to: currentDate) {
            currentDate = newDate
        }
    }
    
    private func weekRangeString(from date: Date, localeIdentifier: String) -> String {
        var calendar = Calendar.current
        calendar.firstWeekday = 2 // Pazartesi
        
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: date) else {
            return ""
        }
        
        let startDate = weekInterval.start
        let endDate = calendar.date(byAdding: .day, value: -1, to: weekInterval.end) ?? weekInterval.end
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: localeIdentifier)
        
        if calendar.isDate(startDate, equalTo: endDate, toGranularity: .month) {
            formatter.dateFormat = "d"
            let startDay = formatter.string(from: startDate)
            formatter.dateFormat = "d MMMM, yyyy"
            let endPart = formatter.string(from: endDate)
            return "\(startDay) - \(endPart)"
        } else {
            formatter.dateFormat = "d MMM"
            let startPart = formatter.string(from: startDate)
            formatter.dateFormat = "d MMM, yyyy"
            let endPart = formatter.string(from: endDate)
            return "\(startPart) - \(endPart)"
        }
    }
}
