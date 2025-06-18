import SwiftUI
import SwiftData

struct IslemEkleView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    
    var duzenlenecekIslem: Islem?
    
    @Query(sort: \Kategori.isim) private var kategoriler: [Kategori]
    
    @State private var isim = ""
    @State private var tutarString = ""
    @State private var tarih = Date()
    @State private var secilenTur: IslemTuru = .gider
    @State private var secilenKategoriID: Kategori.ID?
    @State private var secilenTekrar: TekrarTuru = .tekSeferlik
    
    @State private var orijinalTekrar: TekrarTuru = .tekSeferlik
    
    @State private var guncellemeSecenekleriGoster = false

    private var isFormValid: Bool {
        !isim.trimmingCharacters(in: .whitespaces).isEmpty && !tutarString.isEmpty && secilenKategoriID != nil
    }
    
    var filtrelenmisKategoriler: [Kategori] {
        kategoriler.filter { $0.tur == secilenTur }
    }
    
    private var navigationTitleKey: LocalizedStringKey {
        duzenlenecekIslem == nil ? "transaction.new" : "transaction.edit"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("transaction.type", selection: $secilenTur) {
                        ForEach(IslemTuru.allCases, id: \.self) { tur in
                            // DEĞİŞİKLİK: rawValue'yu LocalizedStringKey içine alıyoruz.
                            Text(LocalizedStringKey(tur.rawValue)).tag(tur)
                        }
                    }.pickerStyle(.segmented)
                }
                Section(header: Text("transaction.section_details")) {
                    TextField("transaction.name_placeholder", text: $isim)
                    TextField("common.amount", text: $tutarString).keyboardType(.decimalPad)
                }
                Section {
                    Picker("common.category", selection: $secilenKategoriID) {
                        Text("transaction.select_category").tag(nil as Kategori.ID?)
                        ForEach(filtrelenmisKategoriler) { kategori in
                            Label { Text(LocalizedStringKey(kategori.localizationKey ?? kategori.isim)) } icon: { Image(systemName: kategori.ikonAdi) }.tag(kategori.id as Kategori.ID?)
                        }
                    }
                    DatePicker("common.date", selection: $tarih, displayedComponents: .date)
                }
                Section {
                    Picker("transaction.recurrence", selection: $secilenTekrar) {
                        ForEach(TekrarTuru.allCases) { tekrar in
                            Label { Text(LocalizedStringKey(tekrar.rawValue)) } icon: { Image(systemName: iconFor(tekrar: tekrar)) }.tag(tekrar)
                        }
                    }
                }
            }
            .navigationTitle(navigationTitleKey).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("common.cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save") { kaydetmeIsleminiBaslat() }.disabled(!isFormValid)
                }
            }
            .onChange(of: secilenTur) {
                if duzenlenecekIslem?.tur != secilenTur {
                     secilenKategoriID = filtrelenmisKategoriler.first?.id
                }
            }
            .onAppear(perform: formuDoldur)
            .confirmationDialog("alert.recurring_transaction", isPresented: $guncellemeSecenekleriGoster, titleVisibility: .visible) {
                Button("alert.update_this_only") { guncelle(tekil: true) }
                Button("alert.update_future") { guncelle(tekil: false) }
                Button("common.cancel", role: .cancel) { }
            }
        }
    }
    
    // Diğer tüm fonksiyonlar aynı kalıyor...
    private func formuDoldur() {
        guard let islem = duzenlenecekIslem else { return }
        isim = islem.isim
        tutarString = String(format: "%.2f", islem.tutar).replacingOccurrences(of: ".", with: ",")
        tarih = islem.tarih
        secilenTur = islem.tur
        secilenKategoriID = islem.kategori?.id
        secilenTekrar = islem.tekrar
        orijinalTekrar = islem.tekrar
    }
    
    private func kaydetmeIsleminiBaslat() {
        if duzenlenecekIslem != nil && orijinalTekrar != .tekSeferlik {
            guncellemeSecenekleriGoster = true
        } else {
            guncelle(tekil: true)
        }
    }
    
    private func guncelle(tekil: Bool) {
        let temizlenmisString = tutarString.replacingOccurrences(of: ",", with: ".")
        let tutar = Double(temizlenmisString) ?? 0.0
        let secilenKategori = kategoriler.first(where: { $0.id == secilenKategoriID })
        let islemToUpdate: Islem
        if let islem = duzenlenecekIslem {
            islemToUpdate = islem
        } else {
            islemToUpdate = Islem(isim: isim, tutar: tutar, tarih: tarih, tur: secilenTur, tekrar: secilenTekrar, kategori: secilenKategori)
            modelContext.insert(islemToUpdate)
            if secilenTekrar != .tekSeferlik {
                yeniSeriOlustur(islem: islemToUpdate)
            }
            NotificationCenter.default.post(name: .transactionsDidChange, object: nil)
            dismiss()
            return
        }
        if !tekil {
            seriyiSil(islem: islemToUpdate, sadeceGelecek: true)
        }
        islemToUpdate.isim = isim
        islemToUpdate.tutar = tutar
        islemToUpdate.tarih = tarih
        islemToUpdate.tur = secilenTur
        islemToUpdate.kategori = secilenKategori
        islemToUpdate.tekrar = secilenTekrar
        if secilenTekrar == .tekSeferlik {
            islemToUpdate.tekrarID = UUID()
        }
        if !tekil && secilenTekrar != .tekSeferlik {
            yeniSeriOlustur(islem: islemToUpdate)
        }
        if orijinalTekrar == .tekSeferlik && secilenTekrar != .tekSeferlik {
             yeniSeriOlustur(islem: islemToUpdate)
        }
        dismiss()
    }
    
    private func seriyiSil(islem: Islem, sadeceGelecek: Bool) {
        let anaIslemID = islem.id
        let tekrarID = islem.tekrarID
        guard tekrarID != UUID() else { return }
        let predicate: Predicate<Islem>
        if sadeceGelecek {
            let baslangicTarihi = islem.tarih
            predicate = #Predicate<Islem> { $0.tekrarID == tekrarID && $0.id != anaIslemID && $0.tarih > baslangicTarihi }
        } else {
            predicate = #Predicate<Islem> { $0.tekrarID == tekrarID && $0.id != anaIslemID }
        }
        try? modelContext.delete(model: Islem.self, where: predicate)
    }
    
    private func yeniSeriOlustur(islem: Islem) {
        if islem.tekrarID == UUID() {
            islem.tekrarID = UUID()
        }
        let tekrarID = islem.tekrarID
        var step = 0
        switch islem.tekrar {
        case .herAy: step = 1
        case .her3Ay: step = 3
        case .her6Ay: step = 6
        case .herYil: step = 12
        case .tekSeferlik: return
        }
        for i in 1...60 {
            if let gelecekTarih = Calendar.current.date(byAdding: .month, value: step * i, to: islem.tarih) {
                let yeniTekrarliIslem = Islem(isim: islem.isim, tutar: islem.tutar, tarih: gelecekTarih, tur: islem.tur, tekrar: islem.tekrar, tekrarID: tekrarID, kategori: islem.kategori)
                modelContext.insert(yeniTekrarliIslem)
            }
        }
    }
}
