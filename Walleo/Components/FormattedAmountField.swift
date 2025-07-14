import SwiftUI
import Combine

struct FormattedAmountField: UIViewRepresentable {
    
    @Binding var valueString: String
    @Binding var isInvalid: Bool
    
    private var placeholderKey: String
    private var locale: Locale

    init(
        _ placeholderKey: String,
        value: Binding<String>,
        isInvalid: Binding<Bool>,
        locale: Locale = .current
    ) {
        self._valueString = value
        self._isInvalid = isInvalid
        self.placeholderKey = placeholderKey
        self.locale = locale
    }

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField(frame: .zero)
        textField.delegate = context.coordinator
        textField.keyboardType = .decimalPad
        textField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        
        // DÜZELTME: Placeholder metnini doğru dilden al.
        textField.placeholder = getLocalizedPlaceholder()
        
        return textField
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        // Dil değişikliği gibi durumlarda placeholder'ı güncelle.
        uiView.placeholder = getLocalizedPlaceholder()
        context.coordinator.numberFormatter.locale = self.locale

        let formattedText = context.coordinator.format(text: valueString)
        if uiView.text != formattedText {
            uiView.text = formattedText
        }
    }
    
    // YENİ YARDIMCI FONKSİYON
    private func getLocalizedPlaceholder() -> String {
        let languageCode = self.locale.identifier
        
        // Doğru dil paketini (bundle) bul
        if let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
           let languageBundle = Bundle(path: path) {
            // Çeviriyi bu paketten al
            return languageBundle.localizedString(forKey: self.placeholderKey, value: self.placeholderKey, table: nil)
        }
        
        // Eğer bir sebepten dil paketi bulunamazsa, standart (genellikle İngilizce) çeviriyi dene.
        return NSLocalizedString(self.placeholderKey, comment: "")
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
            self.numberFormatter.locale = locale
            self.numberFormatter.numberStyle = .decimal
            self.numberFormatter.usesGroupingSeparator = true
            self.numberFormatter.maximumFractionDigits = 2
            
            // Bu kısım aynı kalabilir, çünkü locale'den doğru ayraçları alıyor.
            if locale.identifier.starts(with: "tr") {
                self.numberFormatter.groupingSeparator = "."
                self.numberFormatter.decimalSeparator = ","
            } else {
                self.numberFormatter.groupingSeparator = ","
                self.numberFormatter.decimalSeparator = "."
            }
            
            super.init()
        }
        
        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            let isDeleting = string.isEmpty && range.length > 0
            
            var currentText = textField.text ?? ""
            if let textRange = Range(range, in: currentText) {
                currentText.replaceSubrange(textRange, with: string)
            }

            let decimalSeparator = numberFormatter.decimalSeparator ?? "."
            var cleanString = ""
            if isDeleting {
                 cleanString = currentText.filter { "0123456789\(decimalSeparator)".contains($0) }
            } else {
                 cleanString = (textField.text as NSString?)?.replacingCharacters(in: range, with: string) ?? ""
                 cleanString = cleanString.filter { "0123456789\(decimalSeparator)".contains($0) }
            }
            
            let parts = cleanString.components(separatedBy: decimalSeparator)
            let integerPart = parts[0]
            let fractionPart = parts.count > 1 ? parts[1] : ""
            
            let isLengthValid = integerPart.count <= maxIntegerDigits && fractionPart.count <= maxFractionDigits
            let isFormatValid = parts.count <= 2
            
            if !isLengthValid || !isFormatValid {
                self.isInvalid = true
                return false
            }
            self.isInvalid = false
            
            self.value = cleanString
            
            let formattedText = format(text: cleanString)
            textField.text = formattedText
            
            if let newPosition = textField.position(from: textField.beginningOfDocument, offset: formattedText.count) {
                 textField.selectedTextRange = textField.textRange(from: newPosition, to: newPosition)
            }
            
            return false
        }
        
        func format(text: String) -> String {
            guard !text.isEmpty else { return "" }
            let decimalSeparator = numberFormatter.decimalSeparator ?? "."

            if text == decimalSeparator {
                return "0\(decimalSeparator)"
            }
            
            // DÜZELTME: Sondaki sıfırların kaybolmasını engellemek için
            let parts = text.components(separatedBy: decimalSeparator)
            if parts.count == 2 {
                let fractionDigits = parts[1]
                numberFormatter.minimumFractionDigits = fractionDigits.count
            } else {
                numberFormatter.minimumFractionDigits = 0
            }
            
            let number = numberFormatter.number(from: text)

            if let number = number {
                if text.hasSuffix(decimalSeparator) {
                    return (numberFormatter.string(from: number) ?? "") + decimalSeparator
                }
                return numberFormatter.string(from: number) ?? ""
            }
            
            return text
        }
    }
}
