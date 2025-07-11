import SwiftUI
import SwiftData

struct AileHesabiYonetimView: View {
    @EnvironmentObject var appSettings: AppSettings
    @EnvironmentObject var entitlementManager: EntitlementManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss
    
    @StateObject private var service = AileHesabiService.shared
    
    @State private var aileIsmiGoster = false
    @State private var uyeEkleGoster = false
    @State private var silinecekUye: AileUyesi?
    @State private var silinecekDavet: AileDavet?
    @State private var ayrilmaUyarisiGoster = false
    @State private var davetDetayGoster: AileDavet?
    @State private var uyeSilmeUyarisi = false
    @State private var davetSilmeUyarisi = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                if service.mevcutAileHesabi != nil {
                    aileHesabiDetayView
                } else if !service.bekleyenDavetler.isEmpty {
                    davetlerView
                } else {
                    bosEkranView
                }
                
                if service.isProcessing {
                    ProgressOverlayView(message: service.currentOperation ?? "family.processing")
                }
            }
            .navigationTitle("family.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("common.done") { dismiss() }
                }
            }
            .onAppear {
                service.configure(with: modelContext)
            }
        }
    }
    
    // MARK: - Alt Görünümler
    
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
            
            Button(action: { aileIsmiGoster = true }) {
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
        .sheet(isPresented: $aileIsmiGoster) {
            AileHesabiOlusturView()
        }
    }
    
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
                
                // Bekleyen Davetler (Admin görüşü)
                if aileHesabi.adminID == getCurrentUserID() {
                    let aileID = aileHesabi.id
                    let bekleyenDavetler = service.adminDavetleri.filter { davet in
                        davet.aileHesabiID == aileID && davet.durum == .beklemede
                    }
                    
                    if !bekleyenDavetler.isEmpty {
                        Section("family.pending_invites") {
                            ForEach(bekleyenDavetler) { davet in
                                DavetSatiriAdmin(
                                    davet: davet,
                                    onCancel: {
                                        silinecekDavet = davet
                                        davetSilmeUyarisi = true
                                    }
                                )
                            }
                        }
                    }
                }
                
                // Aile Hesabından Ayrıl
                if aileHesabi.adminID != getCurrentUserID() {
                    Section {
                        Button(role: .destructive, action: { ayrilmaUyarisiGoster = true }) {
                            Label("family.leave", systemImage: "arrow.right.square")
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $uyeEkleGoster) {
            UyeEkleView()
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
                        // Hata göster
                    }
                }
            }
        } message: {
            Text("family.leave.message")
        }
    }
    
    private var davetlerView: some View {
        List {
            Section("family.invitations") {
                ForEach(service.bekleyenDavetler) { davet in
                    DavetSatiriView(davet: davet) {
                        davetDetayGoster = davet
                    }
                }
            }
        }
        .sheet(item: $davetDetayGoster) { davet in
            DavetDetayView(davet: davet)
        }
    }
    
    private func getCurrentUserID() -> String {
        return CloudKitManager.shared.currentUserID ?? ""
    }
    
    private func uyeyiSil(_ uye: AileUyesi) {
        Task {
            do {
                modelContext.delete(uye)
                try modelContext.save()
                // Service'i yeniden configure et
                service.configure(with: modelContext)
            } catch {
                Logger.log("Üye silme hatası: \(error)", log: Logger.service, type: .error)
            }
        }
    }
    
    private func davetiIptalEt(_ davet: AileDavet) {
        Task {
            do {
                davet.durum = .red
                try modelContext.save()
                // Service'i yeniden configure et
                service.configure(with: modelContext)
            } catch {
                Logger.log("Davet iptal hatası: \(error)", log: Logger.service, type: .error)
            }
        }
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

struct DavetSatiriAdmin: View {
    let davet: AileDavet
    let onCancel: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "clock.fill")
                .font(.title2)
                .foregroundColor(.orange)
            
            VStack(alignment: .leading) {
                if davet.davetEdilenID.hasPrefix("pending_") {
                    Text(String(davet.davetEdilenID.dropFirst(8)))
                        .font(.body)
                    Text("Email ile davet edildi")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("Davet Gönderildi")
                        .font(.body)
                    Text("Kullanıcı ID: \(String(davet.davetEdilenID.prefix(8)))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Kalan süre: ")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(davet.gecerlilikTarihi, style: .relative)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button(action: onCancel) {
                Text("İptal")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding(.vertical, 4)
    }
}

struct DavetSatiriView: View {
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

