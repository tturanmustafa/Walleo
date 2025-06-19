// Dosya Adı: IslemEkleView.swift

import SwiftUI
import SwiftData

struct IslemEkleView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    
    var duzenlenecekIslem: Islem?
    
    // MARK: - Veritabanı Sorguları
    @Query(sort: \Kategori.isim) private var kategoriler: [Kategori]
    @Query(sort: \Hesap.olusturmaTarihi) private var tumHesaplar: [Hesap]
    
    // MARK: - State Değişkenleri
    @State private var isim = ""
    @State private var tutarString = ""
    @State private var tarih = Date()
    @State private var secilenTur: IslemTuru = .gider
    @State private var secilenKategoriID: Kategori.ID?
    @State private var secilenHesapID: Hesap.ID?
    @State private var secilenTekrar: TekrarTuru = .tekSeferlik
    
    @State private var orijinalTekrar: TekrarTuru = .tekSeferlik
    @State private var guncellemeSecenekleriGoster = false

    // MARK: - Hesaplanmış Değişkenler
    
    // Formun kaydedilebilir olup olmadığını kontrol eder.
    private var isFormValid: Bool {
        !isim.trimmingCharacters(in: .whitespaces).isEmpty &&
        !tutarString.isEmpty &&
        secilenKategoriID != nil &&
        secilenHesapID != nil
    }
    
    // Seçilen işlem türüne göre kategorileri filtreler.
    var filtrelenmisKategoriler: [Kategori] {
        kategoriler.filter { $0.tur == secilenTur }
    }
    
    // --- YENİ: HESAPLARI FİLTRELEYEN YAPI ---
    // Seçilen işlem türüne göre hesapları filtreler.
    private var filtrelenmisHesaplar: [Hesap] {
        if secilenTur == .gelir {
            // Gelir eklenirken sadece 'Cüzdan' tipi hesaplar gösterilir.
            return tumHesaplar.filter {
                if case .cuzdan = $0.detay { return true }
                return false
            }
        } else { // Gider eklenirken
            // 'Kredi' tipi hesaplar GÖSTERİLMEZ.
            return tumHesaplar.filter {
                if case .kredi = $0.detay { return false }
                return true
            }
        }
    }
    
    // Navigasyon başlığını dinamik olarak belirler.
    private var navigationTitleKey: LocalizedStringKey {
        duzenlenecekIslem == nil ? "transaction.new" : "transaction.edit"
    }

    // MARK: - Body
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(LocalizedStringKey("transaction.type"), selection: $secilenTur) {
                        ForEach(IslemTuru.allCases, id: \.self) { tur in
                            Text(LocalizedStringKey(tur.rawValue)).tag(tur)
                        }
                    }.pickerStyle(.segmented)
                }
                
                Section(header: Text(LocalizedStringKey("transaction.section_details"))) {
                    TextField(LocalizedStringKey("transaction.name_placeholder"), text: $isim)
                    TextField(LocalizedStringKey("common.amount"), text: $tutarString).keyboardType(.decimalPad)
                }
                
                Section {
                    Picker(LocalizedStringKey("common.category"), selection: $secilenKategoriID) {
                        Text(LocalizedStringKey("transaction.select_category")).tag(nil as Kategori.ID?)
                        ForEach(filtrelenmisKategoriler) { kategori in
                            Label {
                                Text(LocalizedStringKey(kategori.localizationKey ?? kategori.isim))
                            } icon: {
                                Image(systemName: kategori.ikonAdi)
                            }.tag(kategori.id as Kategori.ID?)
                        }
                    }
                    
                    Picker("Hesap", selection: $secilenHesapID) {
                        Text("Hesap Seç").tag(nil as Hesap.ID?)
                        // Picker artık filtrelenmiş listeyi kullanıyor.
                        ForEach(filtrelenmisHesaplar) { hesap in
                            Label(hesap.isim, systemImage: hesap.ikonAdi).tag(hesap.id as Hesap.ID?)
                        }
                    }
                    
                    DatePicker(LocalizedStringKey("common.date"), selection: $tarih, displayedComponents: .date)
                }
                
                Section {
                    Picker(LocalizedStringKey("transaction.recurrence"), selection: $secilenTekrar) {
                        ForEach(TekrarTuru.allCases) { tekrar in
                            Label {
                                Text(LocalizedStringKey(tekrar.rawValue))
                            } icon: {
                                Image(systemName: iconFor(tekrar: tekrar))
                            }.tag(tekrar)
                        }
                    }
                }
            }
            .navigationTitle(navigationTitleKey).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(LocalizedStringKey("common.cancel")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("common.save")) { kaydetmeIsleminiBaslat() }.disabled(!isFormValid)
                }
            }
            .onChange(of: secilenTur) {
                // Tür değiştiğinde, seçili kategori ve hesap uyumsuz kalabilir, sıfırlayalım.
                if !filtrelenmisKategoriler.contains(where: { $0.id == secilenKategoriID }) {
                    secilenKategoriID = nil
                }
                if !filtrelenmisHesaplar.contains(where: { $0.id == secilenHesapID }) {
                    secilenHesapID = nil
                }
            }
            .onAppear(perform: formuDoldur)
            .confirmationDialog(LocalizedStringKey("alert.recurring_transaction"), isPresented: $guncellemeSecenekleriGoster, titleVisibility: .visible) {
                Button(LocalizedStringKey("alert.update_this_only")) { guncelle(tekil: true) }
                Button(LocalizedStringKey("alert.update_future")) { guncelle(tekil: false) }
                Button(LocalizedStringKey("common.cancel"), role: .cancel) { }
            }
        }
    }
    
    // MARK: - Fonksiyonlar
    
    private func formuDoldur() {
        guard let islem = duzenlenecekIslem else { return }
        isim = islem.isim
        tutarString = String(format: "%.2f", islem.tutar).replacingOccurrences(of: ".", with: ",")
        tarih = islem.tarih
        secilenTur = islem.tur
        secilenKategoriID = islem.kategori?.id
        secilenHesapID = islem.hesap?.id
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
        let secilenHesap = tumHesaplar.first { $0.id == secilenHesapID }
        
        let islemToUpdate: Islem
        if let islem = duzenlenecekIslem {
            islemToUpdate = islem
        } else {
            islemToUpdate = Islem(isim: isim, tutar: tutar, tarih: tarih, tur: secilenTur, tekrar: secilenTekrar, kategori: secilenKategori, hesap: secilenHesap)
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
        islemToUpdate.hesap = secilenHesap
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
        
        NotificationCenter.default.post(name: .transactionsDidChange, object: nil)
        dismiss()
    }
    
    private func seriyiSil(islem: Islem, sadeceGelecek: Bool) {
        // --- DÜZELTME BURADA ---
        // Predicate içinde kullanacağımız tüm değerleri önce yerel sabitlere atıyoruz.
        let anaIslemID = islem.id
        let tekrarID = islem.tekrarID
        guard tekrarID != UUID() else { return }
        
        let predicate: Predicate<Islem>
        if sadeceGelecek {
            let baslangicTarihi = islem.tarih
            // Predicate artık dışarıdaki sabitleri kullanıyor.
            predicate = #Predicate<Islem> { islem in
                islem.tekrarID == tekrarID &&
                islem.id != anaIslemID &&
                islem.tarih > baslangicTarihi
            }
        } else {
            // Predicate artık dışarıdaki sabitleri kullanıyor.
            predicate = #Predicate<Islem> { islem in
                islem.tekrarID == tekrarID &&
                islem.id != anaIslemID
            }
        }
        // ---
        
        try? modelContext.delete(model: Islem.self, where: predicate)
    }
    
    private func yeniSeriOlustur(islem: Islem) {
        let tekrarID = islem.tekrarID == UUID() ? UUID() : islem.tekrarID
        if islem.tekrarID == UUID() { islem.tekrarID = tekrarID }
        
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
                let yeniTekrarliIslem = Islem(isim: islem.isim, tutar: islem.tutar, tarih: gelecekTarih, tur: islem.tur, tekrar: islem.tekrar, tekrarID: tekrarID, kategori: islem.kategori, hesap: islem.hesap)
                modelContext.insert(yeniTekrarliIslem)
            }
        }
    }
}
