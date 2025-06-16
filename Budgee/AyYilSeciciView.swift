import SwiftUI

struct AyYilSeciciView: View {
    @Environment(\.dismiss) var dismiss
    @State private var seciliTarih: Date
    var onDateSelected: (Date) -> Void
    let yilAraligi: [Int] = Array((Calendar.current.component(.year, from: Date()) - 10)...(Calendar.current.component(.year, from: Date()) + 10))
    @State private var seciliYil: Int
    let ayIsimleri: [String]
    @State private var seciliAy: Int
    
    init(currentDate: Date, onDateSelected: @escaping (Date) -> Void) {
        self._seciliTarih = State(initialValue: currentDate)
        self.onDateSelected = onDateSelected
        let calendar = Calendar.current
        self._seciliYil = State(initialValue: calendar.component(.year, from: currentDate))
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        self.ayIsimleri = formatter.monthSymbols
        self._seciliAy = State(initialValue: calendar.component(.month, from: currentDate) - 1)
    }

    var body: some View {
        NavigationStack {
            HStack {
                Picker("Ay", selection: $seciliAy) {
                    ForEach(0..<ayIsimleri.count, id: \.self) { index in
                        Text(ayIsimleri[index]).tag(index)
                    }
                }.pickerStyle(.wheel)
                Picker("Yıl", selection: $seciliYil) {
                    ForEach(yilAraligi, id: \.self) { yil in
                        Text(String(yil)).tag(yil)
                    }
                }.pickerStyle(.wheel)
            }
            .navigationTitle("Tarih Seç").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Bitti") {
                        var components = Calendar.current.dateComponents([.year, .month], from: seciliTarih)
                        components.month = seciliAy + 1
                        components.year = seciliYil
                        let yeniTarih = Calendar.current.date(from: components) ?? Date()
                        onDateSelected(yeniTarih)
                        dismiss()
                    }
                }
            }
        }
    }
}
