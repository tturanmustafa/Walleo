// Dosya: BildirimlerView.swift

import SwiftUI
import SwiftData

struct BildirimlerView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appSettings: AppSettings
    
    @Query(sort: \Bildirim.olusturmaTarihi, order: .reverse) private var bildirimler: [Bildirim]
    
    @State private var silinecekBildirim: Bildirim?
    @State private var tumunuSilUyarisiGoster = false
    @State private var isDeletingAll = false

    private var hasUnreadNotifications: Bool {
        bildirimler.contains { !$0.okunduMu }
    }

    var body: some View {
        ZStack {
            NavigationStack {
                List {
                    ForEach(bildirimler) { bildirim in
                        let content = bildirim.displayContent(using: appSettings)
                        
                        bildirimSatiri(content: content, okunduMu: bildirim.okunduMu)
                            .onTapGesture {
                                if !bildirim.okunduMu {
                                    bildirim.okunduMu = true
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
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    // GÜNCELLEME: Sol taraftaki butonlar kaldırıldı.
                    
                    ToolbarItem(placement: .topBarTrailing) {
                        HStack {
                            // YENİ: Eylem Menüsü
                            Menu {
                                Button(action: markAllAsRead) {
                                    Label("notifications.mark_all_as_read", systemImage: "envelope.open")
                                }
                                .disabled(!hasUnreadNotifications)
                                
                                Button(role: .destructive, action: { tumunuSilUyarisiGoster = true }) {
                                    Label("notifications.delete_all", systemImage: "trash")
                                }
                                .disabled(bildirimler.isEmpty)
                                
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .font(.title3)
                            }
                            
                            // Bitti butonu menünün yanında.
                            Button("common.done") { dismiss() }
                                .padding(.leading, 8)
                        }
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
    
    private func markAllAsRead() {
        // Fonksiyonun mantığı aynı kalıyor.
        let unread = bildirimler.filter { !$0.okunduMu }
        guard !unread.isEmpty else { return }
        for notification in unread {
            notification.okunduMu = true
        }
        try? modelContext.save()
    }
    
    private func deleteAllNotifications() {
        // Fonksiyonun mantığı aynı kalıyor.
        guard !isDeletingAll else { return }
        Task {
            isDeletingAll = true
            try? await Task.sleep(for: .seconds(0.5))
            try? modelContext.delete(model: Bildirim.self)
            try? modelContext.save()
            isDeletingAll = false
        }
    }
    
    @ViewBuilder
    private func bildirimSatiri(content: BildirimDisplayContent, okunduMu: Bool) -> some View {
        HStack(alignment: .top, spacing: 15) {
            Image(systemName: content.ikonAdi)
                .font(.title2)
                .foregroundColor(content.ikonRengi)
                .frame(width: 30, height: 30)
                .padding(.top, 3)
            
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
                Circle().fill(Color.accentColor).frame(width: 8, height: 8).padding(.top, 6)
            }
        }
        .padding(.vertical, 8)
    }
}
