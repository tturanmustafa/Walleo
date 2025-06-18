import SwiftUI

struct FiltrePillView: View {
    // DEĞİŞİKLİK: 'text: String' yerine 'titleKey: LocalizedStringKey' alıyoruz.
    let titleKey: LocalizedStringKey
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            // DEĞİŞİKLİK: Text artık anahtarı doğrudan kullanarak çeviriyi kendisi yapacak.
            Text(titleKey)
                .font(.footnote).fontWeight(.semibold)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 15).padding(.vertical, 8)
                .background(Capsule().fill(isSelected ? .blue : Color(.systemGray5)))
        }
    }
}
