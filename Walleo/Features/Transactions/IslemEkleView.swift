// DÜZELTME: IslemEkleView.swift

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

    // YENİ: Taksitli işlem state'leri
    @State private var taksitliIslem: Bool = false
    @State private var taksitSayisi: Int = 2
    @State private var isDuzenlemeModuTaksitli: Bool = false
    @State private var taksitGuncellemeUyarisiGoster = false // YENİ: Kaydet'e basınca gösterilecek
    
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
    
    // YENİ: Seçilen hesabın kredi kartı olup olmadığını kontrol
    private var isKrediKartiSecili: Bool {
        guard let hesapID = secilenHesapID,
              let hesap = tumHesaplar.first(where: { $0.id == hesapID }) else {
            return false
        }
        if case .krediKarti = hesap.detay {
            return true
        }
        return false
    }
    
    // YENİ: Taksit önizleme metni
    private var taksitOnizlemeMetni: String {
        let tutar = stringToDouble(tutarString, locale: Locale(identifier: appSettings.languageCode))
        guard tutar > 0 else { return "" }
        
        let aylikTaksit = tutar / Double(taksitSayisi)
        let aylikTaksitStr = formatCurrency(amount: aylikTaksit, currencyCode: appSettings.currencyCode, localeIdentifier: appSettings.languageCode)
        let toplamTutarStr = formatCurrency(amount: tutar, currencyCode: appSettings.currencyCode, localeIdentifier: appSettings.languageCode)
        
        // --- DÜZELTME BAŞLIYOR ---
        // 1. AppSettings'ten doğru dil paketini (.lproj) alıyoruz.
        let languageBundle = Bundle.getLanguageBundle(for: appSettings.languageCode)
        
        // 2. Metin kalıbını bu paketten güvenli bir şekilde çekiyoruz.
        let formatString = languageBundle.localizedString(forKey: "transaction.installment.preview", value: "", table: nil)
        
        // 3. Metni verilerle formatlıyoruz.
        return String(format: formatString, taksitSayisi, aylikTaksitStr, toplamTutarStr)
        // --- DÜZELTME BİTİYOR ---
    }
    
    var filtrelenmisKategoriler: [Kategori] {
        kategoriler.filter { $0.tur == secilenTur }
    }
    
    private var filtrelenmisHesaplar: [Hesap] {
        if secilenTur == .gelir {
            // --- DEĞİŞİKLİK BURADA ---
            // Gelir artık sadece "cüzdan" tipindeki hesaplara eklenebilir.
            // Kredi kartları bu listeden çıkarıldı.
            return tumHesaplar.filter { hesap in
                if case .cuzdan = hesap.detay {
                    return true
                }
                return false
            }
        } else { // Gider durumu
            // Gider, kredi hesapları hariç tüm hesaplardan yapılabilir.
            return tumHesaplar.filter { hesap in
                if case .kredi = hesap.detay {
                    return false
                }
                return true
            }
        }
    }
    
    private var navigationTitleKey: LocalizedStringKey {
        if isDuzenlemeModuTaksitli {
            return "transaction.edit_installment"
        }
        return duzenlenecekIslem == nil ? "transaction.new" : "transaction.edit"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("İşlem Türü", selection: $secilenTur.animation()) {
                        ForEach(IslemTuru.allCases, id: \.self) { tur in
                            Text(LocalizedStringKey(tur.rawValue)).tag(tur)
                        }
                    }
                    .pickerStyle(.segmented)
                    .disabled(isDuzenlemeModuTaksitli) // Taksitli işlem düzenlemede değiştirilemez
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
                    .disabled(isDuzenlemeModuTaksitli) // Taksitli işlem düzenlemede hesap değiştirilemez
                    
                    DatePicker(LocalizedStringKey("common.date"), selection: $tarih, displayedComponents: .date)
                        .onChange(of: tarih) {
                            if bitisTarihi < tarih {
                                bitisTarihi = tarih
                            }
                        }
                }
                
                // YENİ: Taksitli işlem bölümü - DÜZENLEME MODUNDA DA GÖSTER
                if secilenTur == .gider && isKrediKartiSecili {
                    Section {
                        Toggle(LocalizedStringKey("transaction.installment.toggle"), isOn: $taksitliIslem)
                        
                        if taksitliIslem {
                            Stepper(value: $taksitSayisi, in: 2...36) {
                                HStack {
                                    Text(LocalizedStringKey("transaction.installment.count"))
                                    Spacer()
                                    Text("\(taksitSayisi)")
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            if !tutarString.isEmpty && !isTutarGecersiz {
                                Text(taksitOnizlemeMetni)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.top, 4)
                            }
                        }
                    }
                }
                
                // Tekrar bölümü - Taksitli işlem değilse göster
                if !taksitliIslem && !isDuzenlemeModuTaksitli {
                    Section {
                        Picker(LocalizedStringKey("transaction.recurrence"), selection: $secilenTekrar) {
                            ForEach(TekrarTuru.allCases) { tekrar in
                                Label { Text(LocalizedStringKey(tekrar.rawValue)) } icon: { Image(systemName: iconFor(tekrar: tekrar)) }.tag(tekrar)
                            }
                        }
                        
                        if secilenTekrar != .tekSeferlik {
                            DatePicker("form.label.end_date", selection: $bitisTarihi, in: tarih..., displayedComponents: .date)
                        }
                    }
                }
            }
            .onChange(of: isim) {
                suggestCategory(for: isim)
            }
            .onChange(of: secilenHesapID) {
                // Hesap değiştiğinde taksitli işlem toggle'ını kapat
                if !isKrediKartiSecili {
                    taksitliIslem = false
                }
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
                
                // Gelir seçilirse taksitli işlemi kapat
                if secilenTur == .gelir {
                    taksitliIslem = false
                }
            }
            .onAppear(perform: formuDoldur)
            .confirmationDialog(LocalizedStringKey("alert.recurring_transaction"), isPresented: $guncellemeSecenekleriGoster, titleVisibility: .visible) {
                Button(LocalizedStringKey("alert.update_this_only")) { Task { await guncelle(tekil: true) } }
                Button(LocalizedStringKey("alert.update_future")) { Task { await guncelle(tekil: false) } }
                Button(LocalizedStringKey("common.cancel"), role: .cancel) { }
            }
            // YENİ: Taksitli işlem güncelleme uyarısı - KAYDET'E BASINCA GÖSTER
            .alert(LocalizedStringKey("transaction.installment.edit_warning_title"), isPresented: $taksitGuncellemeUyarisiGoster) {
                Button(LocalizedStringKey("common.apply"), role: .destructive) {
                    Task { await taksitliIslemiGuncelle() }
                }
                Button(LocalizedStringKey("common.cancel"), role: .cancel) { }
            } message: {
                Text(LocalizedStringKey("transaction.installment.edit_warning"))
            }
        }
    }
    
    private func formuDoldur() {
        guard let islem = duzenlenecekIslem else { return }
        
        // Taksitli işlem kontrolü
        if islem.taksitliMi, let anaID = islem.anaTaksitliIslemID {
            isDuzenlemeModuTaksitli = true
            
            // Ana işlem bilgilerini yükle
            isim = islem.isim.replacingOccurrences(of: " (\(islem.mevcutTaksitNo)/\(islem.toplamTaksitSayisi))", with: "")
            tutarString = formatAmountForEditing(amount: islem.anaIslemTutari, localeIdentifier: appSettings.languageCode)
            taksitSayisi = islem.toplamTaksitSayisi
            taksitliIslem = true // DÜZELTME: Toggle'ı aç
            
            // İlk taksidin tarihini bul
            let predicate = #Predicate<Islem> { $0.anaTaksitliIslemID == anaID && $0.mevcutTaksitNo == 1 }
            if let ilkTaksit = try? modelContext.fetch(FetchDescriptor(predicate: predicate)).first {
                tarih = ilkTaksit.tarih
            } else {
                tarih = islem.tarih
            }
        } else {
            // Normal işlem
            isim = islem.isim
            tutarString = formatAmountForEditing(amount: islem.tutar, localeIdentifier: appSettings.languageCode)
            tarih = islem.tarih
            secilenTekrar = islem.tekrar
            orijinalTekrar = islem.tekrar
            
            if let bitis = islem.tekrarBitisTarihi {
                bitisTarihi = bitis
            } else if islem.tekrar != .tekSeferlik {
                bitisTarihi = Calendar.current.date(byAdding: .year, value: 1, to: islem.tarih) ?? islem.tarih
            }
        }
        
        isTutarGecersiz = false
        secilenTur = islem.tur
        secilenKategoriID = islem.kategori?.id
        secilenHesapID = islem.hesap?.id
    }
    
    private func kaydetmeIsleminiBaslat() async {
        // Durum 1: Taksitli bir işlemi düzenleme modundayız.
        if isDuzenlemeModuTaksitli {
            // Durum 1a: Kullanıcı işlemi taksitli olarak BIRAKTI (tutar/sayı değişti).
            // Bu, eski seriyi silip yenisini oluşturacağı için yıkıcı bir eylemdir. UYARI GÖSTER.
            if taksitliIslem {
                taksitGuncellemeUyarisiGoster = true
            }
            // Durum 1b: Kullanıcı taksitli işlemi normale ÇEVİRDİ.
            // Bu durumda, uyarı göstermeden doğrudan ana `guncelle` fonksiyonunu çağırıyoruz.
            else {
                await guncelle(tekil: true)
            }
        }
        // Durum 2: Normal bir işlemi düzenliyoruz veya yeni bir işlem oluşturuyoruz.
        else {
            // Tekrarlanan bir normal işlemi düzenliyorsak, seçenekler dialog'unu göster.
            if duzenlenecekIslem != nil && orijinalTekrar != .tekSeferlik {
                guncellemeSecenekleriGoster = true
            }
            // Yeni işlem veya tek seferlik işlem düzenlemesi ise, doğrudan güncelle.
            else {
                await guncelle(tekil: true)
            }
        }
    }
    
    // YENİ: Taksitli işlem güncelleme fonksiyonu
    private func taksitliIslemiGuncelle() async {
        isSaving = true
        defer { isSaving = false }
        
        guard let islem = duzenlenecekIslem,
              let anaID = islem.anaTaksitliIslemID else { return }
        
        do {
            // Eski taksitleri sil
            let predicate = #Predicate<Islem> { $0.anaTaksitliIslemID == anaID }
            let eskiTaksitler = try modelContext.fetch(FetchDescriptor(predicate: predicate))
            
            for taksit in eskiTaksitler {
                modelContext.delete(taksit)
            }
            
            // Yeni taksitleri oluştur
            await taksitliIslemOlustur()
            
            dismiss()
            
        } catch {
            Logger.log("Taksitli işlem güncelleme hatası: \(error)", log: Logger.view, type: .error)
        }
    }
    
    private func guncelle(tekil: Bool) async {
        isSaving = true
        defer { isSaving = false }
        
        do {
            let tutar = stringToDouble(tutarString, locale: Locale(identifier: appSettings.languageCode))
            guard tutar > 0 else {
                Logger.log("Geçersiz tutar: \(tutarString)", log: Logger.view, type: .error)
                return
            }
            
            guard let secilenKategori = kategoriler.first(where: { $0.id == secilenKategoriID }),
                  let secilenHesap = tumHesaplar.first(where: { $0.id == secilenHesapID }) else {
                Logger.log("Kategori veya hesap bulunamadı", log: Logger.view, type: .error)
                return
            }
            
            // DÜZELTME: Düzenleme modunda taksitli işlem değişikliği kontrolü
            if let mevcutIslem = duzenlenecekIslem {
                // Mevcut işlem taksitli mi kontrol et
                let eskidenTaksitliMi = mevcutIslem.taksitliMi
                
                // Taksitli -> Normal veya Normal -> Taksitli dönüşüm
                if eskidenTaksitliMi != taksitliIslem {
                    // Eski taksitleri sil (varsa)
                    if eskidenTaksitliMi, let anaID = mevcutIslem.anaTaksitliIslemID {
                        let predicate = #Predicate<Islem> { $0.anaTaksitliIslemID == anaID }
                        let eskiTaksitler = try modelContext.fetch(FetchDescriptor(predicate: predicate))
                        for taksit in eskiTaksitler {
                            modelContext.delete(taksit)
                        }
                    }
                    
                    if !eskidenTaksitliMi && taksitliIslem {
                        modelContext.delete(mevcutIslem)
                    }
                    
                    // Yeni duruma göre işlem oluştur
                    if taksitliIslem && isKrediKartiSecili {
                        // Normal -> Taksitli
                        await taksitliIslemOlustur()
                    } else {
                        // Taksitli -> Normal
                        let yeniIslem = Islem(
                            isim: isim.trimmingCharacters(in: .whitespaces),
                            tutar: tutar,
                            tarih: tarih,
                            tur: secilenTur,
                            tekrar: secilenTekrar,
                            kategori: secilenKategori,
                            hesap: secilenHesap,
                            tekrarBitisTarihi: secilenTekrar == .tekSeferlik ? nil : bitisTarihi
                        )
                        modelContext.insert(yeniIslem)
                    }
                    
                    try modelContext.save()
                    
                    NotificationCenter.default.post(
                        name: .transactionsDidChange,
                        object: nil,
                        userInfo: ["payload": TransactionChangePayload(
                            type: .update,
                            affectedAccountIDs: [secilenHesap.id],
                            affectedCategoryIDs: [secilenKategori.id]
                        )]
                    )
                    
                    dismiss()
                    return
                }
            }
            
            // Yeni taksitli işlem oluşturma
            if taksitliIslem && secilenTur == .gider && isKrediKartiSecili && duzenlenecekIslem == nil {
                await taksitliIslemOlustur()
                dismiss()
                return
            }
            
            // Normal işlem güncelleme/oluşturma mantığı
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
            
            if !tekil && duzenlenecekIslem != nil {
                await MainActor.run {
                    seriyiSil(islem: islemToUpdate, sadeceGelecek: true)
                }
            }
            
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
            
            if (!tekil && secilenTekrar != .tekSeferlik) ||
               (orijinalTekrar == .tekSeferlik && secilenTekrar != .tekSeferlik) {
                await MainActor.run {
                    yeniSeriOlustur(islem: islemToUpdate, bitis: sonBitisTarihi)
                }
            }
            
            await updateTransactionMemory(name: isim, categoryID: secilenKategoriID)
            
            let changeType: TransactionChangePayload.ChangeType = duzenlenecekIslem == nil ? .add : .update
            let payload = TransactionChangePayload(
                type: changeType,
                affectedAccountIDs: Array(affectedAccountIDs),
                affectedCategoryIDs: [secilenKategori.id]
            )
            
            try modelContext.save()
            
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
        }
    }
    
    // YENİ: Taksitli işlem oluşturma
    private func taksitliIslemOlustur() async {
        let tutar = stringToDouble(tutarString, locale: Locale(identifier: appSettings.languageCode))
        guard tutar > 0,
              let secilenKategori = kategoriler.first(where: { $0.id == secilenKategoriID }),
              let secilenHesap = tumHesaplar.first(where: { $0.id == secilenHesapID }) else {
            return
        }
        
        let anaIslemID = UUID()
        let aylikTaksit = tutar / Double(taksitSayisi)
        let temizIsim = isim.trimmingCharacters(in: .whitespaces)
        
        do {
            for i in 0..<taksitSayisi {
                let taksitTarihi = Calendar.current.date(byAdding: .month, value: i, to: tarih) ?? tarih
                let taksitIsmi = "\(temizIsim) (\(i+1)/\(taksitSayisi))"
                
                let taksit = Islem(
                    isim: taksitIsmi,
                    tutar: aylikTaksit,
                    tarih: taksitTarihi,
                    tur: .gider,
                    kategori: secilenKategori,
                    hesap: secilenHesap,
                    taksitliMi: true,
                    toplamTaksitSayisi: taksitSayisi,
                    mevcutTaksitNo: i + 1,
                    anaTaksitliIslemID: anaIslemID,
                    anaIslemTutari: tutar
                )
                
                modelContext.insert(taksit)
            }
            
            try modelContext.save()
            
            await MainActor.run {
                NotificationCenter.default.post(
                    name: .transactionsDidChange,
                    object: nil,
                    userInfo: ["payload": TransactionChangePayload(
                        type: .add,
                        affectedAccountIDs: [secilenHesap.id],
                        affectedCategoryIDs: [secilenKategori.id]
                    )]
                )
            }
            
        } catch {
            Logger.log("Taksitli işlem oluşturma hatası: \(error)", log: Logger.view, type: .error)
        }
    }
    
    // Diğer fonksiyonlar aynı kalıyor...
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
        guard let bitisTarihi = bitis,
              secilenTekrar != .tekSeferlik else { return }
        
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
