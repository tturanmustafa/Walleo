import SwiftUI

struct FiltrePillView: View {
    let text: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.footnote).fontWeight(.semibold)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 15).padding(.vertical, 8)
                .background(Capsule().fill(isSelected ? .blue : Color(.systemGray5)))
        }
    }
}
