import SwiftUI
import CloudKit

struct UyeEkleView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var cloudKit = CloudKitManager.shared
    
    @State private var email = ""
    @State private var gorunumIsmi = ""
    @State private var isInviting = false
    @State private var hataMesaji: String?
    @State private var showShareSheet = false
    
    private var isFormValid: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty &&
        email.contains("@") &&
        !gorunumIsmi.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("family.invite.email", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .disabled(!cloudKit.isAvailable)
                    
                    TextField("family.invite.display_name", text: $gorunumIsmi)
                        .disabled(!cloudKit.isAvailable)
                } header: {
                    Text("family.invite.header")
                } footer: {
                    Text("family.invite.footer")
                        .font(.caption)
                }
                
                if !cloudKit.isAvailable {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                            Text("iCloud'a giriş yapmanız gerekiyor")
                                .font(.caption)
                        }
                    }
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("family.invite.info")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("family.invite.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                        .disabled(isInviting)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: davetGonder) {
                        if isInviting {
                            ProgressView()
                        } else {
                            Text("family.invite.send")
                        }
                    }
                    .disabled(!isFormValid || isInviting || !cloudKit.isAvailable)
                }
            }
            .alert("family.error.title", isPresented: .constant(hataMesaji != nil)) {
                Button("common.ok") { hataMesaji = nil }
            } message: {
                if let mesaj = hataMesaji {
                    Text(mesaj)
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let share = AileHesabiService.shared.familyShare {
                    CloudSharingView(
                        share: share,
                        container: CKContainer(identifier: "iCloud.com.mustafamt.walleo"),
                        onDismiss: { dismiss() }
                    )
                }
            }
        }
    }
    
    private func davetGonder() {
        Task {
            isInviting = true
            
            do {
                // CloudKit durumunu kontrol et
                guard cloudKit.isAvailable else {
                    hataMesaji = "iCloud'a bağlı değilsiniz. Lütfen Ayarlar'dan iCloud'a giriş yapın."
                    isInviting = false
                    return
                }
                
                // Email ile davet et
                try await AileHesabiService.shared.uyeEkle(
                    email: email,
                    gorunumIsmi: gorunumIsmi
                )
                
                dismiss()
                
            } catch {
                Logger.log("Davet gönderme hatası: \(error)", log: Logger.service, type: .error)
                
                // Daha detaylı hata mesajları
                if error.localizedDescription.contains("not found") {
                    hataMesaji = "Bu email adresiyle kayıtlı bir kullanıcı bulunamadı. Kullanıcının iCloud'a giriş yapmış ve uygulamayı en az bir kez açmış olması gerekiyor."
                } else if error.localizedDescription.contains("permission") {
                    hataMesaji = "Kullanıcı bulma izni verilmemiş. Lütfen Ayarlar > Gizlilik > Kişiler bölümünden uygulamaya izin verin."
                } else {
                    hataMesaji = error.localizedDescription
                }
            }
            
            isInviting = false
        }
    }
}

// CloudKit Share Sheet Wrapper
struct CloudSharingView: UIViewControllerRepresentable {
    let share: CKShare
    let container: CKContainer
    let onDismiss: () -> Void
    
    func makeUIViewController(context: Context) -> UICloudSharingController {
        let controller = UICloudSharingController(share: share, container: container)
        controller.delegate = context.coordinator
        controller.availablePermissions = [.allowReadWrite]
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UICloudSharingController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UICloudSharingControllerDelegate {
        let parent: CloudSharingView
        
        init(_ parent: CloudSharingView) {
            self.parent = parent
        }
        
        func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) {
            Logger.log("Share save failed: \(error)", log: Logger.service, type: .error)
        }
        
        func itemTitle(for csc: UICloudSharingController) -> String? {
            return "Aile Hesabı Daveti"
        }
        
        func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) {
            parent.onDismiss()
        }
        
        func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) {
            parent.onDismiss()
        }
    }
}

