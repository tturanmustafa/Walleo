//
//  FormattedAmountField.swift
//  Walleo
//
//  Created by Mustafa Turan on 25.06.2025.
//


import SwiftUI
import Combine

struct FormattedAmountField: UIViewRepresentable {
    
    @Binding var valueString: String
    @Binding var isInvalid: Bool
    
    private var placeholder: LocalizedStringKey
    private var locale: Locale

    init(
        _ placeholder: LocalizedStringKey,
        value: Binding<String>,
        isInvalid: Binding<Bool>,
        locale: Locale = .current // Varsayılan olarak sistemin local'ini kullanır
    ) {
        self._valueString = value
        self._isInvalid = isInvalid
        self.placeholder = placeholder
        self.locale = locale
    }

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField(frame: .zero)
        textField.delegate = context.coordinator
        textField.keyboardType = .decimalPad
        textField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        
        // Placeholder metnini lokalize olarak ayarla
        let localizedPlaceholder = NSLocalizedString(placeholder.stringKey, comment: "")
        textField.placeholder = localizedPlaceholder
        
        return textField
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        // DÜZELTME BURADA:
        context.coordinator.numberFormatter.locale = self.locale

        // Geri kalan kod aynı şekilde çalışmaya devam ediyor...
        let formattedText = context.coordinator.format(text: valueString)
        if uiView.text != formattedText {
            uiView.text = formattedText
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(value: $valueString, isInvalid: $isInvalid, locale: self.locale)
    }

    class Coordinator: NSObject, UITextFieldDelegate {
        @Binding var value: String
        @Binding var isInvalid: Bool
        
        let numberFormatter: NumberFormatter
        let maxIntegerDigits = 9
        let maxFractionDigits = 2
        
        init(value: Binding<String>, isInvalid: Binding<Bool>, locale: Locale) {
            self._value = value
            self._isInvalid = isInvalid
            
            self.numberFormatter = NumberFormatter()
            self.numberFormatter.locale = locale // Bunu yine de tutuyoruz (para birimi simgeleri vb. için)
            self.numberFormatter.numberStyle = .decimal
            self.numberFormatter.usesGroupingSeparator = true
            self.numberFormatter.maximumFractionDigits = 2
            self.numberFormatter.minimumFractionDigits = 0
            
            // NİHAİ DÜZELTME: Kuralları manuel olarak eziyoruz.
            // Eğer uygulamanın dili "tr" ise, ne olursa olsun bu kuralları kullan.
            if locale.identifier.starts(with: "tr") {
                self.numberFormatter.groupingSeparator = "."
                self.numberFormatter.decimalSeparator = ","
            } else {
                // Diğer tüm diller için (şimdilik) standart İngilizce formatını kullan.
                self.numberFormatter.groupingSeparator = ","
                self.numberFormatter.decimalSeparator = "."
            }
            
            super.init()
        }
        
        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            // Geri silme işlemi için özel kontrol
            let isDeleting = string.isEmpty && range.length > 0
            
            var currentText = textField.text ?? ""
            if let textRange = Range(range, in: currentText) {
                currentText.replaceSubrange(textRange, with: string)
            }

            // 1. Girdiyi temizle (sadece rakamlar ve bir ondalık ayraç kalsın)
            let decimalSeparator = numberFormatter.decimalSeparator ?? "."
            var cleanString = ""
            if isDeleting {
                 cleanString = currentText.filter { "0123456789\(decimalSeparator)".contains($0) }
            } else {
                 cleanString = (textField.text as NSString?)?.replacingCharacters(in: range, with: string) ?? ""
                 cleanString = cleanString.filter { "0123456789\(decimalSeparator)".contains($0) }
            }
            
            
            // 2. Doğrulama yap
            let parts = cleanString.components(separatedBy: decimalSeparator)
            let integerPart = parts[0]
            let fractionPart = parts.count > 1 ? parts[1] : ""
            
            let isLengthValid = integerPart.count <= maxIntegerDigits && fractionPart.count <= maxFractionDigits
            let isFormatValid = parts.count <= 2
            
            if !isLengthValid || !isFormatValid {
                self.isInvalid = true
                return false // Kural dışı girdiyi engelle
            }
            self.isInvalid = false
            
            // 3. Değeri ve TextField'ı güncelle
            self.value = cleanString // Ham, temiz değeri @Binding'e gönder
            
            // Kullanıcıya gösterilecek metni formatla
            let formattedText = format(text: cleanString)
            textField.text = formattedText
            
            // 4. İmleç pozisyonunu ayarla (En kritik kısım)
            // Bu kısım, formatlama sonrası imlecin doğru yerde kalmasını sağlar.
            if let newPosition = textField.position(from: textField.beginningOfDocument, offset: formattedText.count) {
                 textField.selectedTextRange = textField.textRange(from: newPosition, to: newPosition)
            }
            
            return false // TextField'ın kendi güncellemesini engelle, çünkü biz manuel yaptık.
        }
        
        func format(text: String) -> String {
            guard !text.isEmpty else { return "" }
            let decimalSeparator = numberFormatter.decimalSeparator ?? "."

            if text == decimalSeparator {
                return "0\(decimalSeparator)"
            }
            
            // DÜZELTME: Hatalı 'replacingOccurrences' satırı tamamen kaldırıldı.
            // Artık 'text'in zaten doğru ondalık ayracı içerdiğini varsayıyoruz
            // ve doğrudan formatlayıcıya veriyoruz.
            let number = numberFormatter.number(from: text)

            if let number = number {
                // Sayının sonundaki ondalık ayracı koruma mantığı aynı kalıyor
                if text.hasSuffix(decimalSeparator) {
                    return (numberFormatter.string(from: number) ?? "") + decimalSeparator
                }
                return numberFormatter.string(from: number) ?? ""
            }
            
            return text // Eğer formatlama başarısız olursa orijinal metni geri dön
        }
    }
}

// Lokalizasyon için yardımcı extension
extension LocalizedStringKey {
    var stringKey: String {
        let description = "\(self)"
        let components = description.components(separatedBy: "key: \"")
            .map { $0.components(separatedBy: "\",") }
        return components[1][0]
    }
}
