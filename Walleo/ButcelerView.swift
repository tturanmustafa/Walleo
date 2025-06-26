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
                                            silinecekButce = gosterilecekButce.butce
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
            .navigationTitle(LocalizedStringKey("budgets.title"))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { yeniButceEkleGoster = true }) { Image(systemName: "plus") }
                }
            }
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
        .alert(
            LocalizedStringKey("alert.delete_confirmation.title"),
            isPresented: Binding(isPresented: $silinecekButce),
            presenting: silinecekButce
        ) { butce in
            Button(role: .destructive) {
                viewModel?.deleteButce(butce)
            } label: {
                Text("common.delete")
            }
        } message: { butce in
            let dilKodu = appSettings.languageCode
            guard let path = Bundle.main.path(forResource: dilKodu, ofType: "lproj"),
                  let languageBundle = Bundle(path: path) else {
                return Text(butce.isim) // Fallback
            }
            let formatString = languageBundle.localizedString(forKey: "alert.delete_budget.message_format", value: "", table: nil)
            // GÜNCELLENDİ: 'return' eklendi.
            return Text(String(format: formatString, butce.isim))
        }
    }
}
