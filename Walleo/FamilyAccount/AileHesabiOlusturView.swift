//
//  AileHesabiOlusturView.swift
//  Walleo
//
//  Created by Mustafa Turan on 11.07.2025.
//


import SwiftUI

struct AileHesabiOlusturView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appSettings: AppSettings
    
    @State private var aileIsmi = ""
    @State private var isCreating = false
    @State private var hataMesaji: String?
    
    private var isFormValid: Bool {
        !aileIsmi.trimmingCharacters(in: .whitespaces).isEmpty &&
        aileIsmi.count >= 3 &&
        aileIsmi.count <= 30
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("family.create.name_label")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        TextField("family.create.name_placeholder", text: $aileIsmi)
                            .textFieldStyle(.roundedBorder)
                        
                        Text("family.create.name_helper")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        InfoRowView(
                            icon: "person.3.fill",
                            text: "family.create.info.members"
                        )
                        
                        InfoRowView(
                            icon: "lock.shield.fill",
                            text: "family.create.info.admin"
                        )
                        
                        InfoRowView(
                            icon: "icloud.fill",
                            text: "family.create.info.sync"
                        )
                    }
                } header: {
                    Text("family.create.info.header")
                }
            }
            .navigationTitle("family.create.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                        .disabled(isCreating)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: olustur) {
                        if isCreating {
                            ProgressView()
                        } else {
                            Text("common.save")
                        }
                    }
                    .disabled(!isFormValid || isCreating)
                }
            }
            .alert("family.error.title", isPresented: .constant(hataMesaji != nil)) {
                Button("common.ok") { hataMesaji = nil }
            } message: {
                if let mesaj = hataMesaji {
                    Text(mesaj)
                }
            }
        }
    }
    
    private func olustur() {
        Task {
            isCreating = true
            
            do {
                try await AileHesabiService.shared.aileHesabiOlustur(isim: aileIsmi)
                dismiss()
            } catch {
                hataMesaji = error.localizedDescription
            }
            
            isCreating = false
        }
    }
}

struct InfoRowView: View {
    let icon: String
    let text: LocalizedStringKey
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.callout)
                .foregroundColor(.accentColor)
                .frame(width: 24)
            
            Text(text)
                .font(.footnote)
                .foregroundColor(.primary)
        }
    }
}

