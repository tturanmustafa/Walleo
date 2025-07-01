import SwiftUI

struct HaftaSeciciView: View {
    @Environment(\.dismiss) var dismiss
    
    @Binding var currentDate: Date
    @State private var secilenTarih: Date
    
    init(currentDate: Binding<Date>) {
        _currentDate = currentDate
        _secilenTarih = State(initialValue: currentDate.wrappedValue)
    }

    var body: some View {
        NavigationStack {
            // NİHAİ DÜZELTME: DatePicker'ı bir ScrollView içine alıyoruz.
            // Bu, takvimin kendi yüksekliğini serbestçe belirlemesini sağlar
            // ve "height is smaller than" uyarısını ortadan kaldırır.
            ScrollView {
                DatePicker(
                    LocalizedStringKey("week_picker.select_date_label"),
                    selection: $secilenTarih,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .padding(.horizontal)
            }
            .navigationTitle(LocalizedStringKey("week_picker.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("common.cancel")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("common.done")) {
                        currentDate = secilenTarih
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
        }
    }
}
