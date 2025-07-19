// Walleo/Features/Settings/AileHesabiView.swift

import SwiftUI
import SwiftData
import CloudKit

// CKShare'i Identifiable yapmak için wrapper
struct ShareWrapper: Identifiable {
    let id = UUID()
    let share: CKShare
}

struct AileHesabiView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appSettings: AppSettings
    @EnvironmentObject var entitlementManager: EntitlementManager
    @StateObject private var familyManager = FamilySharingManager.shared
    
    @State private var showCreateFamily = false
    @State private var showInviteSheet = false
    @State private var showLeaveConfirmation = false
    
    // DÜZELTME 1: `showShareSheet` state'i kaldırıldı, `shareToPresent` yeterli.
    @State private var shareToPresent: ShareWrapper?
    
    @State private var newFamilyName = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isCurrentUserOwner = false
    
    var body: some View {
        Form {
            if familyManager.currentFamily == nil {
                noFamilySection
            } else {
                familyInfoSection
                familyMembersSection
                familyActionsSection
            }
        }
        .navigationTitle(LocalizedStringKey("settings.family_account"))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await familyManager.loadFamilyData(in: modelContext)
            await checkOwnership()
        }
        .sheet(isPresented: $showCreateFamily) {
            createFamilySheet
        }
        .sheet(isPresented: $showInviteSheet) {
            inviteMemberSheet
        }
        // DÜZELTME 2: İkinci sheet'i burada, ana view'dan sunuyoruz.
        // Bu, sheet içinden sheet açma sorununu ortadan kaldırır.
        .sheet(item: $shareToPresent) { wrapper in
            CloudSharingView(share: wrapper.share, container: CKContainer(identifier: "iCloud.com.mustafamt.walleo"))
        }
        .alert("common.error", isPresented: $showError) {
            Button("common.ok", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .confirmationDialog(
            "family.leave_confirmation_title",
            isPresented: $showLeaveConfirmation,
            titleVisibility: .visible
        ) {
            Button("family.leave_confirm", role: .destructive) {
                Task { await leaveFamily() }
            }
            Button("common.cancel", role: .cancel) { }
        } message: {
            Text("family.leave_confirmation_message")
        }
    }
    
    // MARK: - No Family Section
    private var noFamilySection: some View {
        Section {
            VStack(spacing: 16) {
                Image(systemName: "person.3.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.secondary)
                
                Text("family.no_family_title")
                    .font(.headline)
                
                Text("family.no_family_description")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Button(action: { showCreateFamily = true }) {
                    Label("family.create_family", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding(.vertical, 20)
        }
    }
    
    // MARK: - Family Info Section
    private var familyInfoSection: some View {
        Section("family.info_section") {
            if let family = familyManager.currentFamily {
                LabeledContent("family.name", value: family.isim)
                
                LabeledContent("family.owner") {
                    HStack {
                        Text(family.sahipAdi)
                        if isCurrentUserOwner {
                            Text("(family.you)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                LabeledContent("family.member_count") {
                    Text("\(familyManager.familyMembers.count)")
                }
                
                LabeledContent("family.created_date") {
                    Text(family.olusturmaTarihi, style: .date)
                }
            }
        }
    }
    
    // MARK: - Family Members Section
    private var familyMembersSection: some View {
        Section("family.members_section") {
            ForEach(familyManager.familyMembers) { member in
                HStack {
                    Image(systemName: "person.circle.fill")
                        .font(.title2)
                        .foregroundColor(.accentColor)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(member.adi)
                            .font(.headline)
                        
                        if let email = member.email {
                            Text(email)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Text(member.katilimTarihi, style: .date)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if member.davetDurumu == .beklemede {
                        Text("family.pending")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.orange.opacity(0.2))
                            .foregroundColor(.orange)
                            .cornerRadius(4)
                    }
                }
                .padding(.vertical, 4)
            }
            
            if isCurrentUserOwner {
                Button(action: { showInviteSheet = true }) {
                    Label("family.invite_member", systemImage: "person.badge.plus")
                }
            }
        }
    }
    
    // MARK: - Family Actions Section
    private var familyActionsSection: some View {
        Section {
            if !isCurrentUserOwner {
                Button(role: .destructive) {
                    showLeaveConfirmation = true
                } label: {
                    Label("family.leave_family", systemImage: "arrow.right.square")
                        .foregroundColor(.red)
                }
            } else {
                Text("family.owner_cannot_leave")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Create Family Sheet
    private var createFamilySheet: some View {
        NavigationStack {
            Form {
                Section("family.create_new") {
                    TextField("family.name_placeholder", text: $newFamilyName)
                    
                    Text("family.create_description")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("family.create_title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") {
                        showCreateFamily = false
                        newFamilyName = ""
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.create") {
                        Task { await createFamily() }
                    }
                    .disabled(newFamilyName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
    
    // MARK: - Invite Member Sheet
    private var inviteMemberSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "person.badge.plus")
                    .font(.system(size: 60))
                    .foregroundColor(.accentColor)
                
                Text("family.invite_instructions")
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                if familyManager.isLoadingFamily {
                    ProgressView()
                        .padding()
                } else {
                    Button(action: { Task { await inviteMember() } }) {
                        Label("family.generate_invite_link", systemImage: "link")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.horizontal)
                }
                
                Spacer()
            }
            .padding(.top, 40)
            .navigationTitle("family.invite_member")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.close") {
                        showInviteSheet = false
                    }
                }
            }
        }
        // Bu sheet içindeki `.sheet(item: $shareToPresent)` kaldırıldı.
    }
    
    // MARK: - Helper Functions
    private func checkOwnership() async {
        guard let family = familyManager.currentFamily else {
            isCurrentUserOwner = false
            return
        }
        
        do {
            let (userID, _) = try await familyManager.fetchCurrentUser()
            isCurrentUserOwner = (family.sahipID == userID)
        } catch {
            isCurrentUserOwner = false
        }
    }
    
    private func createFamily() async {
        let familyName = newFamilyName.trimmingCharacters(in: .whitespaces)
        guard !familyName.isEmpty else { return }
        
        do {
            try await familyManager.createFamily(name: familyName, in: modelContext)
            showCreateFamily = false
            newFamilyName = ""
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    private func inviteMember() async {
        guard let family = familyManager.currentFamily else { return }
        
        do {
            let share = try await familyManager.inviteMember(to: family, in: modelContext)
            
            // DÜZELTME 3: Sadece ikinci sheet'i tetikleyip birinciyi kapatıyoruz.
            shareToPresent = ShareWrapper(share: share)
            showInviteSheet = false // Bu satır artık sorun yaratmaz çünkü iki sheet de ana view'dan kontrol ediliyor.
            
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    private func leaveFamily() async {
        guard let family = familyManager.currentFamily else { return }
        
        do {
            try await familyManager.leaveFamily(family, in: modelContext)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

// MARK: - CloudKit Share View Wrapper
struct CloudSharingView: UIViewControllerRepresentable {
    let share: CKShare
    let container: CKContainer
    
    func makeUIViewController(context: Context) -> UICloudSharingController {
        let controller = UICloudSharingController(share: share, container: container)
        controller.availablePermissions = [.allowReadWrite, .allowPrivate]
        // DÜZELTME 4 (Önemli): Controller'a bir delege atayarak kapatıldığını anlayabiliriz,
        // ancak bu senaryoda yeni yapılandırma sayesinde artık gerekli değil.
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UICloudSharingController, context: Context) {}
}
