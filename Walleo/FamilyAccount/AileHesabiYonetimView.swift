import SwiftUI
import SwiftData

struct AileHesabiYonetimView: View {
    @EnvironmentObject var appSettings: AppSettings
    @EnvironmentObject var entitlementManager: EntitlementManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss
    
    @StateObject private var service = AileHesabiService.shared
    
    @State private var selectedTab = 0 // 0: Gruplarım, 1: Davetlerim
    @State private var showCreateFamily = false
    @State private var showEditFamily = false
    @State private var showDeleteWarning = false
    @State private var showMemberWarning = false
    @State private var showPaywall = false
    @State private var uyeEkleGoster = false
    @State private var silinecekUye: AileUyesi?
    @State private var silinecekDavet: AileDavet?
    @State private var ayrilmaUyarisiGoster = false
    @State private var davetDetayGoster: AileDavet?
    @State private var uyeSilmeUyarisi = false
    @State private var davetSilmeUyarisi = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab Seçici
                Picker("", selection: $selectedTab) {
                    Text("family.groups.my_groups").tag(0)
                    Text("family.invites.my_invites").tag(1)
                }
                .pickerStyle(.segmented)
                .padding()
                
                ZStack {
                    if selectedTab == 0 {
                        gruplarimView
                    } else {
                        davetlerimView
                    }
                    
                    if service.isProcessing {
                        ProgressOverlayView(message: service.currentOperation ?? "family.processing")
                    }
                }
            }
            .navigationTitle("family.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if service.mevcutAileHesabi != nil &&
                       service.mevcutAileHesabi?.adminID == getCurrentUserID() {
                        Menu {
                            Button(action: { showEditFamily = true }) {
                                Label("common.edit", systemImage: "pencil")
                            }
                            Button(role: .destructive, action: {
                                checkAndShowDeleteWarning()
                            }) {
                                Label("common.delete", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
            .sheet(isPresented: $showCreateFamily) {
                if entitlementManager.hasPremiumAccess {
                    AileHesabiOlusturView()
                } else {
                    PaywallView()
                }
            }
            .sheet(isPresented: $showEditFamily) {
                if let aile = service.mevcutAileHesabi {
                    AileHesabiDuzenleView(aileHesabi: aile)
                }
            }
            .sheet(isPresented: $uyeEkleGoster) {
                UyeEkleView()
            }
            .sheet(item: $davetDetayGoster) { davet in
                DavetDetayView(davet: davet)
            }
            .onAppear {
                service.configure(with: modelContext)
            }
            // Alerts
            .alert("family.delete.title", isPresented: $showDeleteWarning) {
                Button("common.cancel", role: .cancel) { }
                Button("common.delete", role: .destructive) {
                    deleteFamily()
                }
            } message: {
                Text("family.delete.message.no_members")
            }
            .alert("family.delete.title", isPresented: $showMemberWarning) {
                Button("common.cancel", role: .cancel) { }
                Button("common.delete", role: .destructive) {
                    deleteFamily()
                }
            } message: {
                if let count = service.mevcutAileHesabi?.uyeler?.count {
                    Text("family.warning.delete_with_members \(count)")
                }
            }
            .alert("family.member.remove.title", isPresented: $uyeSilmeUyarisi) {
                Button("common.cancel", role: .cancel) { }
                Button("common.remove", role: .destructive) {
                    if let uye = silinecekUye {
                        uyeyiSil(uye)
                    }
                }
            } message: {
                Text("family.member.remove.message")
            }
            .alert("family.invite.cancel.title", isPresented: $davetSilmeUyarisi) {
                Button("common.cancel", role: .cancel) { }
                Button("family.invite.cancel.confirm", role: .destructive) {
                    if let davet = silinecekDavet {
                        davetiIptalEt(davet)
                    }
                }
            } message: {
                Text("family.invite.cancel.message")
            }
            .alert("family.leave.title", isPresented: $ayrilmaUyarisiGoster) {
                Button("common.cancel", role: .cancel) { }
                Button("family.leave.confirm", role: .destructive) {
                    Task {
                        do {
                            try await service.aileHesabindanAyril()
                            dismiss()
                        } catch {
                            Logger.logFamilyAction("LEAVE_FAMILY_ERROR", details: ["error": error.localizedDescription], type: .error)
                        }
                    }
                }
            } message: {
                Text("family.leave.message")
            }
        }
    }
    
    // MARK: - Gruplarım View
    private var gruplarimView: some View {
        Group {
            if service.mevcutAileHesabi != nil {
                aileHesabiDetayView
            } else {
                bosEkranView
            }
        }
    }
    
    // MARK: - Boş Ekran View
    private var bosEkranView: some View {
        VStack(spacing: 30) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 80))
                .foregroundColor(.secondary)
            
            Text("family.empty.title")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("family.empty.description")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: {
                if CloudKitManager.shared.isAvailable {
                    showCreateFamily = true
                } else {
                    // iCloud uyarısı göster
                    showICloudAlert()
                }
            }) {
                Label("family.create", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Aile Hesabı Detay View
    private var aileHesabiDetayView: some View {
        List {
            if let aileHesabi = service.mevcutAileHesabi {
                // Aile Bilgileri
                Section {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("family.name")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(aileHesabi.isim)
                                .font(.headline)
                        }
                        Spacer()
                        if aileHesabi.adminID == getCurrentUserID() {
                            Text("family.admin")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.accentColor.opacity(0.2))
                                .cornerRadius(6)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                // Aktif Üyeler
                Section("family.members") {
                    if let uyeler = aileHesabi.uyeler?.filter({ $0.durum == .aktif }) {
                        ForEach(uyeler) { uye in
                            UyeSatiriView(
                                uye: uye,
                                isAdmin: aileHesabi.adminID == getCurrentUserID(),
                                isCurrentUser: uye.appleID == getCurrentUserID(),
                                onDelete: {
                                    silinecekUye = uye
                                    uyeSilmeUyarisi = true
                                }
                            )
                        }
                    }
                    
                    if (aileHesabi.uyeler?.count ?? 0) < 4 &&
                       aileHesabi.adminID == getCurrentUserID() {
                        Button(action: { uyeEkleGoster = true }) {
                            Label("family.add_member", systemImage: "person.badge.plus")
                                .foregroundColor(.accentColor)
                        }
                    }
                }
                
                // Aile Hesabından Ayrıl (sadece üye ise)
                if aileHesabi.adminID != getCurrentUserID() {
                    Section {
                        Button(role: .destructive, action: { ayrilmaUyarisiGoster = true }) {
                            Label("family.leave", systemImage: "arrow.right.square")
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Davetlerim View
    private var davetlerimView: some View {
        List {
            // Davet Ettiklerim (Admin için)
            if let aileHesabi = service.mevcutAileHesabi,
               aileHesabi.adminID == getCurrentUserID() {
                let gonderilenDavetler = service.adminDavetleri.filter {
                    $0.durum == .beklemede || $0.durum == .red
                }
                
                if !gonderilenDavetler.isEmpty {
                    Section("family.invites.sent") {
                        ForEach(gonderilenDavetler) { davet in
                            GonderilenDavetSatiri(
                                davet: davet,
                                onCancel: {
                                    if davet.durum == .beklemede {
                                        silinecekDavet = davet
                                        davetSilmeUyarisi = true
                                    }
                                }
                            )
                        }
                    }
                }
            }
            
            // Davet Aldıklarım
            if !service.bekleyenDavetler.isEmpty {
                Section("family.invites.received") {
                    ForEach(service.bekleyenDavetler) { davet in
                        AlinanDavetSatiri(davet: davet) {
                            // Aktif aile kontrolü
                            if service.mevcutAileHesabi != nil {
                                showActiveFamilyWarning()
                            } else {
                                davetDetayGoster = davet
                            }
                        }
                    }
                }
            }
            
            if service.adminDavetleri.isEmpty && service.bekleyenDavetler.isEmpty {
                ContentUnavailableView("family.invites.no_invites",
                                     systemImage: "envelope.open",
                                     description: Text("family.invites.no_invites.desc"))
            }
        }
    }
    
    // MARK: - Helper Functions
    private func getCurrentUserID() -> String {
        return CloudKitManager.shared.currentUserID ?? ""
    }
    
    private func checkAndShowDeleteWarning() {
        if let memberCount = service.mevcutAileHesabi?.uyeler?.count, memberCount > 1 {
            showMemberWarning = true
        } else {
            showDeleteWarning = true
        }
    }
    
    private func deleteFamily() {
        Task {
            do {
                try await service.aileHesabiniSil()
                dismiss()
            } catch {
                Logger.logFamilyAction("DELETE_FAMILY_ERROR", details: ["error": error.localizedDescription], type: .error)
            }
        }
    }
    
    private func uyeyiSil(_ uye: AileUyesi) {
        Task {
            do {
                modelContext.delete(uye)
                try modelContext.save()
                service.configure(with: modelContext)
                Logger.logFamilyAction("MEMBER_REMOVED", details: ["memberID": uye.id.uuidString])
            } catch {
                Logger.logFamilyAction("REMOVE_MEMBER_ERROR", details: ["error": error.localizedDescription], type: .error)
            }
        }
    }
    
    private func davetiIptalEt(_ davet: AileDavet) {
        Task {
            do {
                davet.durum = .red
                try modelContext.save()
                service.configure(with: modelContext)
                Logger.logFamilyAction("INVITE_CANCELLED", details: ["inviteID": davet.id.uuidString])
            } catch {
                Logger.logFamilyAction("CANCEL_INVITE_ERROR", details: ["error": error.localizedDescription], type: .error)
            }
        }
    }
    
    private func showICloudAlert() {
        // iCloud uyarısı göster
    }
    
    private func showActiveFamilyWarning() {
        // Aktif aile uyarısı göster
    }
}

// MARK: - Alt Bileşenler

struct UyeSatiriView: View {
    let uye: AileUyesi
    let isAdmin: Bool
    let isCurrentUser: Bool
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "person.circle.fill")
                .font(.title2)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading) {
                Text(uye.gorunumIsmi)
                    .font(.body)
                HStack {
                    Text(uye.katilimTarihi, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if isCurrentUser {
                        Text("(Sen)")
                            .font(.caption)
                            .foregroundColor(.accentColor)
                    }
                }
            }
            
            Spacer()
            
            // Admin başkalarını silebilir, kendini silemez
            if isAdmin && !isCurrentUser {
                Button(action: onDelete) {
                    Image(systemName: "minus.circle.fill")
                        .foregroundColor(.red)
                }
            }
        }
        .padding(.vertical, 4)
    }
}


struct ProgressOverlayView: View {
    let message: String
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
                
                Text(LocalizedStringKey(message))
                    .font(.body)
                    .foregroundColor(.white)
            }
            .padding(30)
            .background(Material.thick)
            .cornerRadius(15)
            .shadow(radius: 10)
        }
    }
}

struct GonderilenDavetSatiri: View {
    let davet: AileDavet
    let onCancel: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: davet.durum == .beklemede ? "clock.fill" : "xmark.circle.fill")
                .font(.title2)
                .foregroundColor(davet.durum == .beklemede ? .orange : .red)
            
            VStack(alignment: .leading) {
                if davet.davetEdilenID.hasPrefix("pending_") {
                    Text(String(davet.davetEdilenID.dropFirst(8)))
                        .font(.body)
                } else {
                    Text(davet.gorunumIsmi ?? "Davet")
                        .font(.body)
                }
                
                HStack {
                    Text("family.invite.status.\(davet.durum.rawValue)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if davet.durum == .beklemede {
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(davet.gecerlilikTarihi, style: .relative)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            if davet.durum == .beklemede {
                Button(action: onCancel) {
                    Text("common.cancel")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct AlinanDavetSatiri: View {
    let davet: AileDavet
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 4) {
                Text(davet.aileHesabiIsmi)
                    .font(.headline)
                Text(String(format: NSLocalizedString("family.invited_by", comment: ""),
                           davet.davetEdenIsim))
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(davet.olusturmaTarihi, style: .relative)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}
