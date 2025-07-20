// FiltreComponents.swift

import SwiftUI

// MARK: - FiltreButonStyle
struct FiltreButonStyle: ButtonStyle {
    var aktif: Bool = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline)
            .fontWeight(.medium)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                // YENİ: Arka plan rengini optimize et
                RoundedRectangle(cornerRadius: 20)
                    .fill(aktif ? Color.accentColor.opacity(0.15) : Color(.systemGray5))
            )
            .overlay(
                // YENİ: Border'ı sadece aktifken göster
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(aktif ? Color.accentColor : Color.clear, lineWidth: 1.5)
            )
            .foregroundColor(aktif ? .accentColor : .primary)
            // YENİ: Basma efektini optimize et
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .opacity(configuration.isPressed ? 0.8 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - FiltrePillView


// MARK: - FilterBadge
struct FilterBadge: View {
    let count: Int
    
    var body: some View {
        if count > 0 {
            Text("\(count)")
                .font(.caption2.bold())
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(Color.red)
                )
                .transition(.scale.combined(with: .opacity))
        }
    }
}

// MARK: - FilterSectionHeader
struct FilterSectionHeader: View {
    let title: LocalizedStringKey
    let onReset: (() -> Void)?
    
    init(title: LocalizedStringKey, onReset: (() -> Void)? = nil) {
        self.title = title
        self.onReset = onReset
    }
    
    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            Spacer()
            
            if let onReset = onReset {
                Button("common.reset", action: onReset)
                    .font(.subheadline)
                    .foregroundColor(.accentColor)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

// MARK: - EmptyFilterState
struct EmptyFilterState: View {
    let message: LocalizedStringKey
    let icon: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text(message)
                .font(.headline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 40)
    }
}
