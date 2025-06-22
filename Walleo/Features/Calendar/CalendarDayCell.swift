import SwiftUI

struct CalendarDayCell: View {
    @EnvironmentObject var appSettings: AppSettings
    let day: CalendarDay
    
    var body: some View {
        VStack(spacing: 4) {
            Text(day.dayNumber)
                .font(.callout)
                .fontWeight(.medium)
                .frame(maxWidth: .infinity)
                .foregroundColor(day.isCurrentMonth ? .primary : .secondary.opacity(0.5))
            
            if day.netAmount != 0 {
                ViewThatFits {
                    amountText(font: .caption2)
                    amountText(font: .system(size: 8))
                }
            }
        }
        .padding(.vertical, 8)
        .frame(height: 55)
        .background(day.isCurrentMonth ? Color(.systemGray6).opacity(0.4) : Color.clear)
        .cornerRadius(8)
        .overlay(
            Calendar.current.isDateInToday(day.date) && day.isCurrentMonth ?
                RoundedRectangle(cornerRadius: 8).stroke(Color.red, lineWidth: 1.5) : nil
        )
    }
    
    func amountText(font: Font) -> some View {
        Text(formatCurrency(
            amount: day.netAmount,
            currencyCode: appSettings.currencyCode,
            localeIdentifier: appSettings.languageCode
        ))
            .font(font)
            .fontWeight(.bold)
            .lineLimit(1)
            .foregroundColor(day.netAmount > 0 ? .green : .red)
    }
}
