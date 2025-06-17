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
