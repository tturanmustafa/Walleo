import SwiftUI

struct FiltrePillView: View {
    let titleKey: LocalizedStringKey
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.body)
                        .transition(.scale.combined(with: .opacity))
                }
                
                Text(titleKey)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(
                // YENİ: Arka plan animasyonunu optimize et
                RoundedRectangle(cornerRadius: 25)
                    .fill(isSelected ? Color.accentColor : Color(.systemGray5))
            )
            .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(PlainButtonStyle())
        // YENİ: Animasyonu sadece değişiklik olduğunda uygula
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}
