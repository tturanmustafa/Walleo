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
                        // GÜNCELLEME: Başlangıç tarihi değiştiğinde, bitiş tarihinin de ondan ileri bir tarihte kalmasını sağla
                        .onChange(of: tarih) {
                            if bitisTarihi < tarih {
                                bitisTarihi = tarih
                            }
                        }
                }
                
                Section {
                    Picker(LocalizedStringKey("transaction.recurrence"), selection: $secilenTekrar) {
                        ForEach(TekrarTuru.allCases) { tekrar in
                            Label { Text(LocalizedStringKey(tekrar.rawValue)) } icon: { Image(systemName: iconFor(tekrar: tekrar)) }.tag(tekrar)
                        }
                    }
                    
                    // YENİ: Bitiş tarihi belirleme arayüzü eklendi.
                    // Sadece tekrarlanan bir işlem türü seçildiğinde görünür olacak.
                    // --- DEĞİŞİKLİK BURADA ---
                    // Toggle kaldırıldı. Tekrarlanan bir işlem seçildiğinde DatePicker doğrudan görünüyor.
                    if secilenTekrar != .tekSeferlik {
                        DatePicker("form.label.end_date", selection: $bitisTarihi, in: tarih..., displayedComponents: .date)
                    }                }
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
        
        // Bitiş tarihi alanını doldurma güncellendi
        if let bitis = islem.tekrarBitisTarihi {
            bitisTarihi = bitis
        } else {
            // Eğer kayıtlı bitiş tarihi yoksa ama tekrarlanan bir işlemse, varsayılan bir değer ata
            if islem.tekrar != .tekSeferlik {
                bitisTarihi = Calendar.current.date(byAdding: .year, value: 1, to: islem.tarih) ?? islem.tarih
            }
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
        defer { isSaving = false } // Her durumda isSaving'i false yap
        
        do {
            // Güvenli double dönüşümü
            let tutar = stringToDouble(tutarString, locale: Locale(identifier: appSettings.languageCode))
            guard tutar > 0 else {
                Logger.log("Geçersiz tutar: \(tutarString)", log: Logger.view, type: .error)
                return
            }
            
            // Kategori ve hesap kontrolü
            guard let secilenKategori = kategoriler.first(where: { $0.id == secilenKategoriID }),
                  let secilenHesap = tumHesaplar.first(where: { $0.id == secilenHesapID }) else {
                Logger.log("Kategori veya hesap bulunamadı", log: Logger.view, type: .error)
                return
            }
            
            let sonBitisTarihi: Date? = secilenTekrar == .tekSeferlik ? nil : bitisTarihi
            
            var affectedAccountIDs: Set<UUID> = [secilenHesap.id]
            
            let islemToUpdate: Islem
            if let islem = duzenlenecekIslem {
                if let eskiHesapID = islem.hesap?.id {
                    affectedAccountIDs.insert(eskiHesapID)
                }
                islemToUpdate = islem
            } else {
                islemToUpdate = Islem(
                    isim: isim,
                    tutar: tutar,
                    tarih: tarih,
                    tur: secilenTur,
                    tekrar: secilenTekrar,
                    kategori: secilenKategori,
                    hesap: secilenHesap,
                    tekrarBitisTarihi: sonBitisTarihi
                )
                modelContext.insert(islemToUpdate)
            }
            
            // Güvenli seri silme
            if !tekil && duzenlenecekIslem != nil {
                await MainActor.run {
                    seriyiSil(islem: islemToUpdate, sadeceGelecek: true)
                }
            }
            
            // İşlem güncelleme
            islemToUpdate.isim = isim.trimmingCharacters(in: .whitespaces)
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
            
            // Yeni seri oluşturma kontrolü
            if (!tekil && secilenTekrar != .tekSeferlik) ||
               (orijinalTekrar == .tekSeferlik && secilenTekrar != .tekSeferlik) {
                await MainActor.run {
                    yeniSeriOlustur(islem: islemToUpdate, bitis: sonBitisTarihi)
                }
            }
            
            // Hafıza güncelleme
            await updateTransactionMemory(name: isim, categoryID: secilenKategoriID)
            
            // Değişiklik bildirimi
            let changeType: TransactionChangePayload.ChangeType = duzenlenecekIslem == nil ? .add : .update
            let payload = TransactionChangePayload(
                type: changeType,
                affectedAccountIDs: Array(affectedAccountIDs),
                affectedCategoryIDs: [secilenKategori.id]
            )
            
            // Model kaydetme
            try modelContext.save()
            
            // Bildirimler
            await MainActor.run {
                NotificationCenter.default.post(
                    name: .transactionsDidChange,
                    object: nil,
                    userInfo: ["payload": payload]
                )
                BudgetService.shared.runBudgetChecks(
                    for: islemToUpdate,
                    in: modelContext,
                    settings: appSettings
                )
            }
            
            dismiss()
            
        } catch {
            Logger.log("İşlem kaydetme hatası: \(error)", log: Logger.view, type: .error)
            // Kullanıcıya hata göster
            await MainActor.run {
                // Hata alert'i göstermek için state ekleyebilirsiniz
            }
        }
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
    
    // --- DEĞİŞİKLİK BURADA: FONKSİYON TAMAMEN YENİLENDİ ---
    private func yeniSeriOlustur(islem: Islem, bitis: Date?) {
        guard let bitisTarihi = bitis,
              secilenTekrar != .tekSeferlik else { return }
        
        // Maksimum tekrar sayısı kontrolü (performans için)
        let maxTekrar = 100
        var tekrarSayisi = 0
        
        let tekrarID = islem.tekrarID == UUID() ? UUID() : islem.tekrarID
        if islem.tekrarID == UUID() {
            islem.tekrarID = tekrarID
        }
        
        var step: Calendar.Component
        var value: Int
        
        switch islem.tekrar {
            case .herAy: (step, value) = (.month, 1)
            case .her3Ay: (step, value) = (.month, 3)
            case .her6Ay: (step, value) = (.month, 6)
            case .herYil: (step, value) = (.year, 1)
            case .tekSeferlik: return
        }
        
        var mevcutTarih = islem.tarih
        let takvim = Calendar.current
        
        while let gelecekTarih = takvim.date(byAdding: step, value: value, to: mevcutTarih),
              gelecekTarih <= bitisTarihi,
              tekrarSayisi < maxTekrar {
            
            let yeniTekrarliIslem = Islem(
                isim: islem.isim,
                tutar: islem.tutar,
                tarih: gelecekTarih,
                tur: islem.tur,
                tekrar: islem.tekrar,
                tekrarID: tekrarID,
                kategori: islem.kategori,
                hesap: islem.hesap,
                tekrarBitisTarihi: bitisTarihi
            )
            
            modelContext.insert(yeniTekrarliIslem)
            mevcutTarih = gelecekTarih
            tekrarSayisi += 1
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
