// Dosya: IslemEkleView.swift

import SwiftUI
import SwiftData

struct IslemEkleView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appSettings: AppSettings
    
    var duzenlenecekIslem: Islem?
    
    @Query(sort: \Kategori.isim) private var kategoriler: [Kategori]
    @Query(sort: \Hesap.olusturmaTarihi) private var tumHesaplar: [Hesap]
    
    @State private var isim = ""
    @State private var tutarString = ""
    @State private var tarih = Date()
    @State private var secilenTur: IslemTuru = .gider
    @State private var secilenKategoriID: Kategori.ID?
    @State private var secilenHesapID: Hesap.ID?
    @State private var secilenTekrar: TekrarTuru = .tekSeferlik
    
    @State private var bitisTarihiEtkin: Bool = false
    @State private var bitisTarihi: Date = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    
    @State private var orijinalTekrar: TekrarTuru = .tekSeferlik
    @State private var guncellemeSecenekleriGoster = false

    @State private var isTutarGecersiz = false
    @State private var isSaving = false

    private var isFormValid: Bool {
        !isim.trimmingCharacters(in: .whitespaces).isEmpty &&
        !tutarString.isEmpty &&
        !isTutarGecersiz &&
        secilenKategoriID != nil &&
        secilenHesapID != nil
    }
    
    var filtrelenmisKategoriler: [Kategori] {
        kategoriler.filter { $0.tur == secilenTur }
    }
    
    private var filtrelenmisHesaplar: [Hesap] {
        if secilenTur == .gelir {
            return tumHesaplar.filter {
                if case .cuzdan = $0.detay { return true }
                if case .krediKarti = $0.detay { return true }
                return false
            }
        } else {
            return tumHesaplar.filter { if case .kredi = $0.detay { return false }; return true }
        }
    }
    
    private var navigationTitleKey: LocalizedStringKey {
        duzenlenecekIslem == nil ? "transaction.new" : "transaction.edit"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("İşlem Türü", selection: $secilenTur.animation()) {
                        ForEach(IslemTuru.allCases, id: \.self) { tur in
                            // GÜNCELLEME: tur.localized yerine, SwiftUI'ın kendi
                            // dil motorunu kullanan LocalizedStringKey yapısını kullanıyoruz.
                            // Bu, AppModels'ı değiştirmeden sorunu çözer.
                            Text(LocalizedStringKey(tur.rawValue)).tag(tur)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Section(header: Text(LocalizedStringKey("transaction.section_details"))) {
                    LabeledTextField(
                        label: "form.label.transaction_name",
                        placeholder: "transaction.name_placeholder",
                        text: $isim
                    )
                    
                    VStack(alignment: .leading) {
                        LabeledAmountField(
                            label: "form.label.amount",
                            placeholder: "transaction.amount_placeholder",
                            valueString: $tutarString,
                            isInvalid: $isTutarGecersiz,
                            locale: Locale(identifier: appSettings.languageCode)
                        )

                        if isTutarGecersiz {
                            Text(LocalizedStringKey("validation.error.invalid_amount_format")).font(.caption).foregroundColor(.red).padding(.top, 2)
                        }
                    }
                }
                
                Section {
                    Picker(LocalizedStringKey("common.category"), selection: $secilenKategoriID) {
                        Text(LocalizedStringKey("transaction.select_category")).tag(nil as Kategori.ID?)
                        ForEach(filtrelenmisKategoriler) { kategori in
                            Label { Text(LocalizedStringKey(kategori.localizationKey ?? kategori.isim)) } icon: { Image(systemName: kategori.ikonAdi) }.tag(kategori.id as Kategori.ID?)
                        }
                    }
                    Picker(LocalizedStringKey("common.account"), selection: $secilenHesapID) {
                        Text(LocalizedStringKey("common.select_account")).tag(nil as Hesap.ID?)
                        ForEach(filtrelenmisHesaplar) { hesap in
                            Label(hesap.isim, systemImage: hesap.ikonAdi).tag(hesap.id as Hesap.ID?)
                        }
                    }
                    DatePicker(LocalizedStringKey("common.date"), selection: $tarih, displayedComponents: .date)
                }
                
                Section {
                    Picker(LocalizedStringKey("transaction.recurrence"), selection: $secilenTekrar) {
                        ForEach(TekrarTuru.allCases) { tekrar in
                            Label { Text(LocalizedStringKey(tekrar.rawValue)) } icon: { Image(systemName: iconFor(tekrar: tekrar)) }.tag(tekrar)
                        }
                    }
                    
                    // YENİ: Bitiş tarihi belirleme arayüzü eklendi.
                    // Sadece tekrarlanan bir işlem türü seçildiğinde görünür olacak.
                    if secilenTekrar != .tekSeferlik {
                        Toggle("form.label.set_end_date", isOn: $bitisTarihiEtkin.animation())
                        
                        if bitisTarihiEtkin {
                            DatePicker("form.label.end_date", selection: $bitisTarihi, in: tarih..., displayedComponents: .date)
                        }
                    }
                }
            }
            // KATEGORİ ÖNERME MANTIĞI İÇİN YENİ EKLENEN MODIFIER
            .onChange(of: isim) {
                suggestCategory(for: isim)
            }
            .disabled(isSaving)
            .navigationTitle(navigationTitleKey).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("common.cancel")) { dismiss() }.disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button(LocalizedStringKey("common.save")) { Task { await kaydetmeIsleminiBaslat() } }
                        .disabled(!isFormValid)
                    }
                }
            }
            .onChange(of: secilenTur) {
                if !filtrelenmisKategoriler.contains(where: { $0.id == secilenKategoriID }) { secilenKategoriID = nil }
                if !filtrelenmisHesaplar.contains(where: { $0.id == secilenHesapID }) { secilenHesapID = nil }
            }
            .onAppear(perform: formuDoldur)
            .confirmationDialog(LocalizedStringKey("alert.recurring_transaction"), isPresented: $guncellemeSecenekleriGoster, titleVisibility: .visible) {
                Button(LocalizedStringKey("alert.update_this_only")) { Task { await guncelle(tekil: true) } }
                Button(LocalizedStringKey("alert.update_future")) { Task { await guncelle(tekil: false) } }
                Button(LocalizedStringKey("common.cancel"), role: .cancel) { }
            }
        }
    }
    
    private func formuDoldur() {
        guard let islem = duzenlenecekIslem else { return }
        isim = islem.isim
        tutarString = formatAmountForEditing(amount: islem.tutar, localeIdentifier: appSettings.languageCode)
        isTutarGecersiz = false
        tarih = islem.tarih
        secilenTur = islem.tur
        secilenKategoriID = islem.kategori?.id
        secilenHesapID = islem.hesap?.id
        secilenTekrar = islem.tekrar
        orijinalTekrar = islem.tekrar
        
        // GÜNCELLEME: Düzenleme modunda bitiş tarihi alanlarını doldurma
        if let bitis = islem.tekrarBitisTarihi {
            bitisTarihiEtkin = true
            bitisTarihi = bitis
        } else {
            bitisTarihiEtkin = false
        }
    }
    
    private func kaydetmeIsleminiBaslat() async {
        if duzenlenecekIslem != nil && orijinalTekrar != .tekSeferlik {
            guncellemeSecenekleriGoster = true
        } else {
            await guncelle(tekil: true)
        }
    }
    
    private func guncelle(tekil: Bool) async {
        isSaving = true
        
        let tutar = stringToDouble(tutarString, locale: Locale(identifier: appSettings.languageCode))
        let secilenKategori = kategoriler.first(where: { $0.id == secilenKategoriID })
        let secilenHesap = tumHesaplar.first { $0.id == secilenHesapID }
        
        // GÜNCELLEME: Bitiş tarihi, toggle'ın durumuna göre ayarlanır.
        let sonBitisTarihi: Date? = bitisTarihiEtkin ? bitisTarihi : nil
        
        var affectedAccountIDs: Set<UUID> = []
        if let hesapID = secilenHesap?.id { affectedAccountIDs.insert(hesapID) }
        
        let islemToUpdate: Islem
        if let islem = duzenlenecekIslem {
            if let eskiHesapID = islem.hesap?.id { affectedAccountIDs.insert(eskiHesapID) }
            islemToUpdate = islem
        } else {
            islemToUpdate = Islem(isim: isim, tutar: tutar, tarih: tarih, tur: secilenTur, tekrar: secilenTekrar, kategori: secilenKategori, hesap: secilenHesap, tekrarBitisTarihi: sonBitisTarihi)
            modelContext.insert(islemToUpdate)
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
        islemToUpdate.tekrarBitisTarihi = sonBitisTarihi
        
        if secilenTekrar == .tekSeferlik {
            islemToUpdate.tekrarID = UUID()
        }
        
        if !tekil && secilenTekrar != .tekSeferlik {
            yeniSeriOlustur(islem: islemToUpdate, bitis: sonBitisTarihi)
        }
        
        if orijinalTekrar == .tekSeferlik && secilenTekrar != .tekSeferlik {
             yeniSeriOlustur(islem: islemToUpdate, bitis: sonBitisTarihi)
        }
        
        var affectedCategoryIDs: [UUID] = []
        if let kategoriID = secilenKategori?.id {
            affectedCategoryIDs.append(kategoriID)
        }
        
        await updateTransactionMemory(name: isim, categoryID: secilenKategoriID)
        
        let changeType: TransactionChangePayload.ChangeType = duzenlenecekIslem == nil ? .add : .update
        let payload = TransactionChangePayload(
            type: changeType,
            affectedAccountIDs: Array(affectedAccountIDs),
            affectedCategoryIDs: affectedCategoryIDs
        )
        
        do {
            try modelContext.save()
            NotificationCenter.default.post(name: .transactionsDidChange, object: nil, userInfo: ["payload": payload])
            BudgetService.shared.runBudgetChecks(for: islemToUpdate, in: modelContext, settings: appSettings)
        } catch {
            Logger.log("IslemEkleView: Kaydetme sırasında kritik hata: \(error.localizedDescription)", log: Logger.data, type: .fault)
        }
        
        isSaving = false
        dismiss()
    }
    
    private func seriyiSil(islem: Islem, sadeceGelecek: Bool) {
        let anaIslemID = islem.id
        let tekrarID = islem.tekrarID
        guard tekrarID != UUID() else { return }
        
        let predicate: Predicate<Islem>
        if sadeceGelecek {
            let baslangicTarihi = islem.tarih
            predicate = #Predicate<Islem> { islem in
                islem.tekrarID == tekrarID && islem.id != anaIslemID && islem.tarih > baslangicTarihi
            }
        } else {
            predicate = #Predicate<Islem> { islem in islem.tekrarID == tekrarID && islem.id != anaIslemID }
        }
        
        try? modelContext.delete(model: Islem.self, where: predicate)
    }
    
    private func yeniSeriOlustur(islem: Islem, bitis: Date?) {
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
                // GÜNCELLEME: Bitiş tarihi kontrolü eklendi.
                if let bitisTarihi = bitis, gelecekTarih > bitisTarihi {
                    break
                }
                
                let yeniTekrarliIslem = Islem(isim: islem.isim, tutar: islem.tutar, tarih: gelecekTarih, tur: islem.tur, tekrar: islem.tekrar, tekrarID: tekrarID, kategori: islem.kategori, hesap: islem.hesap, tekrarBitisTarihi: bitis)
                modelContext.insert(yeniTekrarliIslem)
            }
        }
    }
    
    private func suggestCategory(for name: String) {
        guard duzenlenecekIslem == nil else { return }
        let nameKey = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard nameKey.count > 2 else { return }
        let descriptor = FetchDescriptor<TransactionMemory>(predicate: #Predicate { $0.transactionNameKey == nameKey })
        
        if let memory = try? modelContext.fetch(descriptor).first {
            if filtrelenmisKategoriler.contains(where: { $0.id == memory.lastCategoryID }) {
                self.secilenKategoriID = memory.lastCategoryID
            }
        }
    }
    
    private func updateTransactionMemory(name: String, categoryID: Kategori.ID?) async {
        guard let categoryID = categoryID else { return }
        let nameKey = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !nameKey.isEmpty else { return }
        
        let descriptor = FetchDescriptor<TransactionMemory>(predicate: #Predicate { $0.transactionNameKey == nameKey })
        
        do {
            if let existingMemory = try modelContext.fetch(descriptor).first {
                existingMemory.lastCategoryID = categoryID
            } else {
                let newMemory = TransactionMemory(transactionNameKey: nameKey, lastCategoryID: categoryID)
                modelContext.insert(newMemory)
            }
        } catch {
            Logger.log("TransactionMemory güncellenirken hata oluştu: \(error.localizedDescription)", log: Logger.data, type: .error)
        }
    }
}
