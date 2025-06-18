//
//  FiltreButonStyle.swift
//  Budgee
//
//  Created by Mustafa Turan on 18.06.2025.
//


import SwiftUI

struct FiltreButonStyle: ButtonStyle {
    var aktif: Bool = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(aktif ? Color.blue.opacity(0.15) : Color(.systemGray5))
            .foregroundColor(aktif ? .blue : .primary)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(aktif ? .blue : Color.clear, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}