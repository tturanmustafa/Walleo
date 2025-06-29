// DOSYA: LabeledAmountField.swift

import SwiftUI

struct LabeledAmountField: View {
    let label: LocalizedStringKey
    // --- DEĞİŞİKLİK BURADA ---
    // 'placeholder' artık bir LocalizedStringKey değil, String tipinde bir anahtar.
    let placeholder: String
    
    @Binding var valueString: String
    @Binding var isInvalid: Bool
    let locale: Locale

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.accentColor)
                .opacity(valueString.isEmpty ? 0 : 1)
                .offset(y: valueString.isEmpty ? 10 : 0)

            // 'placeholder' artık doğru tipte (String) olduğu için bu satır hata vermeyecek.
            FormattedAmountField(
                placeholder,
                value: $valueString,
                isInvalid: $isInvalid,
                locale: locale
            )
        }
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: valueString.isEmpty)
        .padding(.vertical, 8)
    }
}
