import SwiftUI
import SwiftData

struct ButcelerView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appSettings: AppSettings
    @State private var viewModel: ButcelerViewModel?

    @State private var currentTitle: String = "" // Başlığı tutacak yeni State

    @State private var yeniButceEkleGoster = false
    @State private var duzenlenecekButce: Butce?

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
                                                viewModel.deleteButce(gosterilecekButce.butce)
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
            .navigationTitle(currentTitle) // Başlık artık State'ten geliyor
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { yeniButceEkleGoster = true }) { Image(systemName: "plus") }
                }
            }
        }
        .onAppear(perform: updateTitle) // Ekran ilk açıldığında başlığı ayarla
        .onChange(of: appSettings.languageCode) { // Dil değiştiğinde başlığı güncelle
            updateTitle()
        }
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
    
    private func updateTitle() {
        self.currentTitle = NSLocalizedString("budgets.title", comment: "")
    }
}
