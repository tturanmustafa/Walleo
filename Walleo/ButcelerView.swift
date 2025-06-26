import SwiftUI
import SwiftData

struct ButcelerView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appSettings: AppSettings
    @State private var viewModel: ButcelerViewModel?

    @State private var yeniButceEkleGoster = false
    @State private var duzenlenecekButce: Butce?
    @State private var silinecekButce: Butce?


    var body: some View {
        NavigationStack {
            Group {
                if let viewModel = viewModel {
                    if viewModel.gosterilecekButceler.isEmpty {
                        ContentUnavailableView(
                            LocalizedStringKey("budgets.empty.title"),
                            systemImage: "chart.pie.fill",
                            description: Text(LocalizedStringKey("budgets.empty.description"))
                        )
                    } else {
                        ScrollView {
                            VStack(spacing: 15) {
                                ForEach(viewModel.gosterilecekButceler) { gosterilecekButce in
                                    NavigationLink(destination: ButceDetayView(butce: gosterilecekButce.butce, modelContext: modelContext)) {
                                        ButceKartView(
                                            gosterilecekButce: gosterilecekButce,
                                            onEdit: {
                                                duzenlenecekButce = gosterilecekButce.butce
                                            },
                                            onDelete: {
                                                silinecekButce = gosterilecekButce.butce
                                            }
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    .contextMenu {
                                        Button(action: {
                                            duzenlenecekButce = gosterilecekButce.butce
                                        }) {
                                            Label("common.edit", systemImage: "pencil")
                                        }
                                        Button(role: .destructive, action: {
                                            viewModel.deleteButce(gosterilecekButce.butce)
                                        }) {
                                            Label("common.delete", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                            .padding()
                        }
                    }
                } else {
                    ProgressView()
                }
            }
            .navigationTitle(LocalizedStringKey("budgets.title")) // DÜZELTİLDİ
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { yeniButceEkleGoster = true }) { Image(systemName: "plus") }
                }
            }
        }
        // Manuel başlık güncelleme kodları kaldırıldı
        .sheet(isPresented: $yeniButceEkleGoster, onDismiss: {
            Task { await viewModel?.butceDurumlariniHesapla() }
        }) {
            ButceEkleDuzenleView()
        }
        .sheet(item: $duzenlenecekButce, onDismiss: {
            Task { await viewModel?.butceDurumlariniHesapla() }
        }) { butce in
            ButceEkleDuzenleView(duzenlenecekButce: butce)
        }
        .task {
            if viewModel == nil {
                viewModel = ButcelerViewModel(modelContext: modelContext)
            }
            await viewModel?.butceDurumlariniHesapla()
        }
    }
}
