// Dosya: BildirimlerView.swift

import SwiftUI
import SwiftData

struct BildirimlerView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appSettings: AppSettings
    
    @Query(sort: \Bildirim.olusturmaTarihi, order: .reverse) private var bildirimler: [Bildirim]
    
    // GÜNCELLEME: ViewModel kaldırıldı. View artık kendi durumunu yönetiyor.
    @State private var silinecekBildirim: Bildirim?
    @State private var tumunuSilUyarisiGoster = false
    @State private var isDeletingAll = false

    var body: some View {
        ZStack {
            NavigationStack {
                List {
                    ForEach(bildirimler) { bildirim in
                        // İçerik, doğrudan modelin kendisinden çağırılıyor.
                        let content = bildirim.displayContent(using: appSettings)
                        
                        bildirimSatiri(content: content, okunduMu: bildirim.okunduMu)
                            .onTapGesture {
                                if !bildirim.okunduMu {
                                    bildirim.okunduMu = true
                                    // Değişikliği anında kaydet.
                                    try? modelContext.save()
                                }
                            }
                            .swipeActions {
                                Button(role: .destructive) {
                                    silinecekBildirim = bildirim
                                } label: { Label("common.delete", systemImage: "trash") }
                            }
                    }
                }
                .overlay {
                    if bildirimler.isEmpty && !isDeletingAll {
                        ContentUnavailableView("notifications.no_notifications_title", systemImage: "bell.slash", description: Text("notifications.no_notifications_desc"))
                    }
                }
                .navigationTitle("notifications.title")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItemGroup(placement: .cancellationAction) {
                        // Butonlar artık bu View içindeki private fonksiyonları çağırıyor.
                        Button("notifications.mark_all_as_read") {
                            markAllAsRead()
                        }
                        .disabled(bildirimler.isEmpty)
                        
                        Button("notifications.delete_all") {
                            tumunuSilUyarisiGoster = true
                        }
                        .tint(.red)
                        .disabled(bildirimler.isEmpty)
                    }
                    
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("common.done") { dismiss() }
                    }
                }
                .alert(
                    LocalizedStringKey("alert.delete_confirmation.title"),
                    isPresented: Binding(isPresented: $silinecekBildirim),
                    presenting: silinecekBildirim
                ) { bildirim in
                    Button(role: .destructive) {
                        modelContext.delete(bildirim)
                        try? modelContext.save()
                    } label: { Text("common.delete") }
                }
                .alert(
                    LocalizedStringKey("alert.delete_all_notifications.title"),
                    isPresented: $tumunuSilUyarisiGoster
                ) {
                    Button(role: .destructive, action: deleteAllNotifications) { Text("common.delete") }
                } message: {
                    Text("alert.delete_all_notifications.message")
                }
            }
            .disabled(isDeletingAll)

            if isDeletingAll {
                ProgressView("Tümü Siliniyor...")
                    .padding(25)
                    .background(Material.thick)
                    .cornerRadius(10)
                    .shadow(radius: 5)
            }
        }
    }
    
    // GÜNCELLEME: Fonksiyonlar artık ViewModel'da değil, View'ın kendi private fonksiyonları.
    private func markAllAsRead() {
        let unread = bildirimler.filter { !$0.okunduMu }
        guard !unread.isEmpty else { return }
        for notification in unread {
            notification.okunduMu = true
        }
        try? modelContext.save()
    }
    
    private func deleteAllNotifications() {
        guard !isDeletingAll else { return }
        Task {
            isDeletingAll = true
            // Arka planda silmek yerine, az sayıda bildirim için ana thread'de silmek
            // daha basit ve hatasız olabilir. Çok sayıda bildirim olursa bu tekrar değerlendirilir.
            try? modelContext.delete(model: Bildirim.self)
            try? modelContext.save()
            isDeletingAll = false
        }
    }
    
    // Satır view'ı basit bir content yapısı alıyor.
    @ViewBuilder
    private func bildirimSatiri(content: BildirimDisplayContent, okunduMu: Bool) -> some View {
        HStack(spacing: 15) {
            Image(systemName: content.ikonAdi)
                .font(.title2)
                .foregroundColor(content.ikonRengi)
                .frame(width: 30)
                .padding(.top, 5)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(content.baslik).fontWeight(.semibold)
                Text(content.aciklamaLine1).font(.caption).foregroundColor(.secondary)
                if let line2 = content.aciklamaLine2 {
                    Text(line2).font(.caption).foregroundColor(.secondary)
                }
                if let line3 = content.aciklamaLine3 {
                    Text(line3).font(.caption).foregroundColor(.secondary)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
            
            if !okunduMu {
                Circle().fill(Color.accentColor).frame(width: 8, height: 8)
            }
        }
        .padding(.vertical, 8)
    }
}
