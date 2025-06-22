import SwiftUI

extension View {
    func recurringTransactionAlert(
        for item: Binding<Islem?>,
        onDeleteSingle: @escaping (Islem) -> Void,
        onDeleteSeries: @escaping (Islem) -> Void
    ) -> some View {
        self.confirmationDialog(
            "alert.recurring_transaction",
            isPresented: .constant(item.wrappedValue != nil),
            titleVisibility: .visible
        ) {
            Button("alert.delete_this_only", role: .destructive) {
                if let islem = item.wrappedValue {
                    onDeleteSingle(islem)
                }
                item.wrappedValue = nil
            }
            Button("alert.delete_series", role: .destructive) {
                if let islem = item.wrappedValue {
                    onDeleteSeries(islem)
                }
                item.wrappedValue = nil
            }
            Button("common.cancel", role: .cancel) {
                item.wrappedValue = nil
            }
        }
        // DEĞİŞİKLİK: Tekrar eden metni gösteren 'message' bloğu kaldırıldı.
        /*
        message: {
            Text("alert.recurring_transaction")
        }
        */
    }
}

struct AmountInputValidator: ViewModifier {
    @Binding var text: String
    @Binding var isInvalid: Bool

    func body(content: Content) -> some View {
        content
            .onChange(of: text) { newValue in
                // Mevcut haneKontrolluDogrula fonksiyonunun mantığı buraya taşınacak.
                // Sadece bir örnek:
                if newValue.isEmpty { isInvalid = false; return }
                let normalizedString = newValue.replacingOccurrences(of: ",", with: ".")
                guard normalizedString.components(separatedBy: ".").count <= 2, Double(normalizedString) != nil else { isInvalid = true; return }
                let parts = normalizedString.components(separatedBy: ".")
                if parts[0].count > 9 || (parts.count == 2 && parts[1].count > 2) {
                    isInvalid = true
                } else {
                    isInvalid = false
                }
            }
    }
}

extension View {
    func validateAmountInput(text: Binding<String>, isInvalid: Binding<Bool>) -> some View {
        self.modifier(AmountInputValidator(text: text, isInvalid: isInvalid))
    }
}
