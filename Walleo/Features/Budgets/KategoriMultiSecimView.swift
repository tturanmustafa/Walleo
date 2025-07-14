import SwiftUI
import SwiftData

struct KategoriMultiSecimView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var secilenKategoriIDleri: Set<UUID>

    // Query'yi burada sadece tanımlıyoruz, başlatmıyoruz.
    @Query private var giderKategorileri: [Kategori]

    // NİHAİ ÇÖZÜM:
    // init metodu içinde, sorguyu (predicate) oluşturmadan önce
    // ihtiyacımız olan değeri bir sabite atıyoruz.
    init(secilenKategoriIDleri: Binding<Set<UUID>>) {
        _secilenKategoriIDleri = secilenKategoriIDleri
        
        let giderTuruRawValue = IslemTuru.gider.rawValue
        
        let predicate = #Predicate<Kategori> { kategori in
            kategori.turRawValue == giderTuruRawValue
        }
        
        // Şimdi @Query'yi bu güvenli predicate ile başlatıyoruz.
        _giderKategorileri = Query(filter: predicate, sort: \Kategori.isim)
    }

    var body: some View {
        NavigationStack {
            List(giderKategorileri) { kategori in
                Button(action: {
                    toggleSecim(id: kategori.id)
                }) {
                    HStack {
                        Image(systemName: secilenKategoriIDleri.contains(kategori.id) ? "checkmark.circle.fill" : "circle")
                            .font(.title2)
                            .foregroundColor(secilenKategoriIDleri.contains(kategori.id) ? .accentColor : .secondary)
                        
                        Image(systemName: kategori.ikonAdi)
                            .frame(width: 30, height: 30)
                            .background(kategori.renk.opacity(0.2))
                            .foregroundColor(kategori.renk)
                            .cornerRadius(6)
                        
                        Text(LocalizedStringKey(kategori.localizationKey ?? kategori.isim))
                        
                        Spacer()
                    }
                }
                .foregroundColor(.primary)
            }
            .navigationTitle(LocalizedStringKey("budgets.form.select_categories"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("common.done")) {
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
        }
    }

    private func toggleSecim(id: UUID) {
        if secilenKategoriIDleri.contains(id) {
            secilenKategoriIDleri.remove(id)
        } else {
            secilenKategoriIDleri.insert(id)
        }
    }
}
