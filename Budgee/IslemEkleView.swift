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
    
    private var navigationTitle: String {
        duzenlenecekIslem == nil ? "Yeni İşlem" : "İşlemi Düzenle"
    }

    var body: some View {
        NavigationStack {
            Form {
                // Form içeriği aynı
                Section {
                    Picker("İşlem Türü", selection: $secilenTur) {
                        Text("Gider").tag(IslemTuru.gider)
                        Text("Gelir").tag(IslemTuru.gelir)
                    }.pickerStyle(.segmented)
                }
                Section(header: Text("Detaylar")) {
                    TextField("İşlem Adı (örn: Akşam Yemeği)", text: $isim)
                    TextField("Tutar", text: $tutarString).keyboardType(.decimalPad)
                }
                Section {
                    Picker("Kategori", selection: $secilenKategoriID) {
                        Text("Kategori Seçin").tag(nil as Kategori.ID?)
                        ForEach(filtrelenmisKategoriler) { kategori in
                            Label { Text(kategori.isim) } icon: { Image(systemName: kategori.ikonAdi) }.tag(kategori.id as Kategori.ID?)
                        }
                    }
                    DatePicker("Tarih", selection: $tarih, displayedComponents: .date).environment(\.locale, Locale(identifier: "tr_TR"))
                }
                Section {
                    Picker("Tekrarlanma", selection: $secilenTekrar) {
                        ForEach(TekrarTuru.allCases) { tekrar in
                            Label { Text(tekrar.rawValue) } icon: { Image(systemName: iconFor(tekrar: tekrar)) }.tag(tekrar)
                        }
                    }
                }
            }
            .navigationTitle(navigationTitle).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("İptal") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") {
                        kaydetmeIsleminiBaslat()
                    }.disabled(!isFormValid)
                }
            }
            .onChange(of: secilenTur) {
                if duzenlenecekIslem?.tur != secilenTur {
                     secilenKategoriID = filtrelenmisKategoriler.first?.id
                }
            }
            .onAppear(perform: formuDoldur)
            .confirmationDialog("Bu tekrarlayan bir işlemin parçası.", isPresented: $guncellemeSecenekleriGoster, titleVisibility: .visible) {
                Button("Sadece Bu İşlemi Güncelle") { guncelle(tekil: true) }
                Button("Bu ve Gelecekteki İşlemleri Güncelle") { guncelle(tekil: false) }
                Button("İptal", role: .cancel) { }
            }
        }
    }
    
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
    
    // YENİ VE GELİŞTİRİLMİŞ GÜNCELLEME FONKSİYONU
    private func guncelle(tekil: Bool) {
        let temizlenmisString = tutarString.replacingOccurrences(of: ",", with: ".")
        let tutar = Double(temizlenmisString) ?? 0.0
        let secilenKategori = kategoriler.first(where: { $0.id == secilenKategoriID })
        
        let islemToUpdate: Islem
        
        if let islem = duzenlenecekIslem {
            islemToUpdate = islem
        } else {
            // Bu, yeni bir işlemdir, seri mantığı burada başlamaz.
            islemToUpdate = Islem(isim: isim, tutar: tutar, tarih: tarih, tur: secilenTur, tekrar: secilenTekrar, kategori: secilenKategori)
            modelContext.insert(islemToUpdate)
            // Eğer yeni eklenen işlem tekrarlıysa, seriyi oluştur.
            if secilenTekrar != .tekSeferlik {
                yeniSeriOlustur(islem: islemToUpdate)
            }
            dismiss()
            return
        }

        // --- DÜZENLEME MANTIĞI ---
        
        // 1. Önce eski gelecekteki işlemleri sil (Eğer seri güncellenecekse)
        if !tekil {
            seriyiSil(islem: islemToUpdate, sadeceGelecek: true)
        }
        
        // 2. Ana (düzenlenen) işlemi güncelle
        islemToUpdate.isim = isim
        islemToUpdate.tutar = tutar
        islemToUpdate.tarih = tarih
        islemToUpdate.tur = secilenTur
        islemToUpdate.kategori = secilenKategori
        islemToUpdate.tekrar = secilenTekrar
        
        // Eğer tek seferliğe çevrildiyse, tekrarID'yi sıfırla.
        if secilenTekrar == .tekSeferlik {
            islemToUpdate.tekrarID = UUID() // Yeni benzersiz ID ata
        }
        
        // 3. Yeni seriyi oluştur (Eğer seri güncelleniyorsa VE tekrarlanma hala aktifse)
        if !tekil && secilenTekrar != .tekSeferlik {
            yeniSeriOlustur(islem: islemToUpdate)
        }
        
        // 4. Tek seferlik bir işlem, tekrarlı hale getirildiyse
        if orijinalTekrar == .tekSeferlik && secilenTekrar != .tekSeferlik {
             yeniSeriOlustur(islem: islemToUpdate)
        }
        
        dismiss()
    }
    
    // ---- YARDIMCI FONKSİYONLAR ----
    
    private func seriyiSil(islem: Islem, sadeceGelecek: Bool) {
        // İşlemin kendisini silmemek için ID'sinin eşleşmediğinden emin ol
        let anaIslemID = islem.id
        let tekrarID = islem.tekrarID
        guard tekrarID != UUID() else { return } // TekrarID yoksa çık
        
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
        // Eğer ana işlemin bir tekrarID'si yoksa veya sıfırlandıysa, yeni bir tane ata
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

        // Gelecek 5 yıl (60 ay) için işlem oluştur
        for i in 1...60 {
            if let gelecekTarih = Calendar.current.date(byAdding: .month, value: step * i, to: islem.tarih) {
                let yeniTekrarliIslem = Islem(isim: islem.isim, tutar: islem.tutar, tarih: gelecekTarih, tur: islem.tur, tekrar: islem.tekrar, tekrarID: tekrarID, kategori: islem.kategori)
                modelContext.insert(yeniTekrarliIslem)
            }
        }
    }
}
