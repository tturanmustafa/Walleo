//
//  LabeledTextField.swift
//  Walleo
//
//  Created by Mustafa Turan on 29.06.2025.
//


import SwiftUI

struct LabeledTextField: View {
    let label: LocalizedStringKey
    let placeholder: LocalizedStringKey
    @Binding var text: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // DÜZELTME 2: Etiket artık sadece metin girildiğinde görünüyor.
            Text(label)
                .font(.caption)
                .foregroundColor(.accentColor)
                .opacity(text.isEmpty ? 0 : 1) // Boşken görünmez yap
                .offset(y: text.isEmpty ? 10 : 0) // Yumuşak geçiş için
            
            // DÜZELTME 1: Hizalama sorunu çözüldü.
            TextField(placeholder, text: $text)
        }
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: text.isEmpty)
        .padding(.vertical, 8)
    }
}