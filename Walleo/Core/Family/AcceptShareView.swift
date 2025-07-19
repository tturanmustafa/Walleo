//
//  AcceptShareView.swift
//  Walleo
//
//  Created by Mustafa Turan on 19.07.2025.
//


// Walleo/Features/Family/AcceptShareView.swift

import SwiftUI
import CloudKit

struct AcceptShareView: View {
    let metadata: CKShare.Metadata
    @Environment(\.dismiss) private var dismiss
    @StateObject private var familyManager = FamilySharingManager.shared
    
    @State private var isAccepting = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var acceptanceComplete = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                Image(systemName: "person.3.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.accentColor)
                    .padding(.top, 40)
                
                VStack(spacing: 16) {
                    Text("family.invitation_title")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    if let title = metadata.share[CKShare.SystemFieldKey.title] as? String {
                        Text(title)
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("family.invitation_description")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                }
                
                Spacer()
                
                VStack(spacing: 16) {
                    if isAccepting {
                        ProgressView("family.accepting_invitation")
                            .padding()
                    } else if acceptanceComplete {
                        Label("family.invitation_accepted", systemImage: "checkmark.circle.fill")
                            .font(.headline)
                            .foregroundColor(.green)
                    } else {
                        Button(action: acceptInvitation) {
                            Label("family.accept_invitation", systemImage: "person.badge.plus")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        
                        Button(action: { dismiss() }) {
                            Text("common.cancel")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 40)
            }
            .navigationTitle("family.join_family")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if acceptanceComplete {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("common.done") { dismiss() }
                    }
                }
            }
            .alert("common.error", isPresented: $showError) {
                Button("common.ok", role: .cancel) { dismiss() }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func acceptInvitation() {
        isAccepting = true
        
        Task {
            do {
                try await familyManager.acceptInvitation(metadata)
                
                await MainActor.run {
                    isAccepting = false
                    acceptanceComplete = true
                }
                
                // Biraz bekle ve kapat
                try await Task.sleep(nanoseconds: 2_000_000_000) // 2 saniye
                dismiss()
                
            } catch {
                await MainActor.run {
                    isAccepting = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}