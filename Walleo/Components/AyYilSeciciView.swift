import SwiftUI

struct AyYilSeciciView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appSettings: AppSettings
    
    // Parametreler
    let currentDate: Date
    let onDateSelected: (Date) -> Void

    // View'in kendi durumu (State)
    @State private var seciliYil: Int
    @State private var seciliAy: Int
    @State private var ayIsimleri: [String] = [] // Ay isimlerini artık State içinde tutuyoruz

    // init metodu, sadece başlangıç değerlerini atamak için kullanılır.
    init(currentDate: Date, onDateSelected: @escaping (Date) -> Void) {
        self.currentDate = currentDate
        self.onDateSelected = onDateSelected
        
        let calendar = Calendar.current
        _seciliYil = State(initialValue: calendar.component(.year, from: currentDate))
        _seciliAy = State(initialValue: calendar.component(.month, from: currentDate) - 1)
    }

    var body: some View {
        NavigationStack {
            VStack {
                // 'body' içinde artık hesaplama yok, sadece mevcut durumu gösteriyor.
                HStack {
                    Picker("month_picker.month", selection: $seciliAy) {
                        ForEach(0..<ayIsimleri.count, id: \.self) { index in
                            // ayIsimleri boşsa çökmemesi için kontrol
                            Text(ayIsimleri.isEmpty ? "" : ayIsimleri[index]).tag(index)
                        }
                    }.pickerStyle(.wheel)
                    
                    Picker("month_picker.year", selection: $seciliYil) {
                        ForEach(yilAraligi, id: \.self) { yil in
                            Text(String(yil)).tag(yil)
                        }
                    }.pickerStyle(.wheel)
                }
            }
            .navigationTitle("month_picker.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .confirmationAction) {
                    Button("common.done") {
                        // Date() yerine currentDate kullanarak başlangıç tarihini koruyoruz.
                        var components = Calendar.current.dateComponents([.year, .month], from: currentDate)
                        components.month = seciliAy + 1
                        components.year = seciliYil
                        let yeniTarih = Calendar.current.date(from: components) ?? currentDate
                        onDateSelected(yeniTarih)
                        dismiss()
                    }
                }
            }
        }
        // Görünüm ilk açıldığında ay isimlerini hesapla
        .onAppear(perform: updateMonthSymbols)
        // Dil ayarı değiştiğinde ay isimlerini TEKRAR hesapla
        .onChange(of: appSettings.languageCode) {
            updateMonthSymbols()
        }
    }
    
    // Sabitler
    private let yilAraligi: [Int] = Array((Calendar.current.component(.year, from: Date()) - 10)...(Calendar.current.component(.year, from: Date()) + 10))
    
    // Yardımcı Fonksiyon
    private func updateMonthSymbols() {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: appSettings.languageCode)
        self.ayIsimleri = formatter.monthSymbols ?? []
    }
}
