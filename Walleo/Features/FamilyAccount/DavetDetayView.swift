//
//  DavetDetayView.swift
//  Walleo
//
//  Created by Mustafa Turan on 11.07.2025.
//


import SwiftUI

struct DavetDetayView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appSettings: AppSettings
    
    let davet: AileDavet
    @State private var isProcessing = false
    @State private var hataMesaji: String?
    @State private var onayUyarisiGoster = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Üst Başlık
                VStack(spacing: 20) {
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.accentColor)
                    
                    Text("family.invitation.title")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    VStack(spacing: 8) {
                        Text(davet.davetEdenIsim)
                            .font(.title3)
                            .fontWeight(.semibold)
                        
                        Text("family.invitation.invites_you")
                            .font(.body)
                            .foregroundColor(.secondary)
                        
                        Text(davet.aileHesabiIsmi)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.accentColor)
                    }
                }
                .padding(.vertical, 40)
                
                // Bilgi Kartları
                VStack(spacing: 16) {
                    WarningCard(
                        icon: "exclamationmark.triangle.fill",
                        title: "family.invitation.warning.title",
                        message: "family.invitation.warning.message",
                        color: .orange
                    )
                    
                    InfoCard(
                        icon: "arrow.triangle.2.circlepath",
                        title: "family.invitation.sync.title",
                        message: "family.invitation.sync.message"
                    )
                    
                    InfoCard(
                        icon: "clock.fill",
                        title: "family.invitation.expiry.title",
                        message: LocalizedStringKey("family.invitation.expiry.message \(remainingDays())")
                    )
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Alt Butonlar
                VStack(spacing: 12) {
                    Button(action: { onayUyarisiGoster = true }) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("family.invitation.accept")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .cornerRadius(12)
                    }
                    
                    Button(action: reddet) {
                        Text("family.invitation.decline")
                            .font(.headline)
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(12)
                    }
                }
                .padding()
                .disabled(isProcessing)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("common.close") { dismiss() }
                        .disabled(isProcessing)
                }
            }
            .confirmationDialog(
                "family.invitation.confirm.title",
                isPresented: $onayUyarisiGoster
            ) {
                Button("family.invitation.confirm.accept", role: .destructive) {
                    kabul()
                }
                Button("common.cancel", role: .cancel) { }
            } message: {
                Text("family.invitation.confirm.message")
            }
            .alert("family.error.title", isPresented: .constant(hataMesaji != nil)) {
                Button("common.ok") { hataMesaji = nil }
            } message: {
                if let mesaj = hataMesaji {
                    Text(mesaj)
                }
            }
            .overlay {
                if isProcessing {
                    ProcessingOverlay()
                }
            }
        }
    }
    
    private func remainingDays() -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date(), to: davet.gecerlilikTarihi)
        return components.day ?? 0
    }
    
    private func kabul() {
        Task {
            isProcessing = true
            
            do {
                try await AileHesabiService.shared.daveteYanitVer(davet: davet, kabul: true)
                dismiss()
            } catch {
                hataMesaji = error.localizedDescription
            }
            
            isProcessing = false
        }
    }
    
    private func reddet() {
        Task {
            isProcessing = true
            
            do {
                try await AileHesabiService.shared.daveteYanitVer(davet: davet, kabul: false)
                dismiss()
            } catch {
                hataMesaji = error.localizedDescription
            }
            
            isProcessing = false
        }
    }
}

struct WarningCard: View {
    let icon: String
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    let color: Color
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(color)
                
                Text(message)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

struct InfoCard: View {
    let icon: String
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.accentColor)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(message)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct ProcessingOverlay: View {
    @State private var rotation = 0.0
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 50))
                    .foregroundColor(.white)
                    .rotationEffect(.degrees(rotation))
                    .onAppear {
                        withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                            rotation = 360
                        }
                    }
                
                Text("family.processing.sync")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("family.processing.please_wait")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(40)
            .background(Material.thick)
            .cornerRadius(20)
        }
    }
}

