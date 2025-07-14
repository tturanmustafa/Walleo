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

extension Binding {
    /// İsteğe bağlı (optional) bir state'e bağlı Binding<Bool> oluşturur.
    ///
    /// Bu Binding, optional state bir değere sahip olduğunda `true`, `nil` olduğunda `false` olur.
    /// Bu Binding'e `false` değeri atandığında, orijinal optional state'i `nil` yapar.
    ///
    /// Kullanım: `.alert(isPresented: Binding(isPresented: $silinecekOge), ...)`
    init<Wrapped>(isPresented: Binding<Wrapped?>) where Value == Bool {
        self.init(
            get: { isPresented.wrappedValue != nil },
            set: { newValue in
                // Eğer alert kapatılıyorsa (newValue false ise),
                // orijinal state'i nil yaparak işlemi tamamla.
                if !newValue {
                    isPresented.wrappedValue = nil
                }
            }
        )
    }
}
