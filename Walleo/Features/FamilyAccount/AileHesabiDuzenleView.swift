import SwiftUI

struct AileHesabiDuzenleView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let aileHesabi: AileHesabi
    
    @State private var yeniIsim: String = ""
    @State private var isEditing = false
    @State private var hataMesaji: String?
    
    private var isFormValid: Bool {
        !yeniIsim.trimmingCharacters(in: .whitespaces).isEmpty &&
        yeniIsim.count >= 3 &&
        yeniIsim.count <= 30 &&
        yeniIsim != aileHesabi.isim
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("family.create.name_placeholder", text: $yeniIsim)
                        .textFieldStyle(.roundedBorder)
                } header: {
                    Text("family.name")
                } footer: {
                    Text("family.create.name_helper")
                        .font(.caption)
                }
            }
            .navigationTitle("family.edit.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                        .disabled(isEditing)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: kaydet) {
                        if isEditing {
                            ProgressView()
                        } else {
                            Text("common.save")
                        }
                    }
                    .disabled(!isFormValid || isEditing)
                }
            }
            .onAppear {
                yeniIsim = aileHesabi.isim
                // Service'i configure et
                AileHesabiService.shared.configure(with: modelContext)
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
    
    private func kaydet() {
        Task {
            isEditing = true
            
            do {
                try await AileHesabiService.shared.aileHesabiniDuzenle(yeniIsim: yeniIsim)
                dismiss()
            } catch {
                hataMesaji = error.localizedDescription
            }
            
            isEditing = false
        }
    }
}
