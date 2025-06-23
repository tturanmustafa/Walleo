// Dosya Adı: KrediEkleView.swift (NİHAİ ÇÖZÜM)

import SwiftUI
import SwiftData
import Combine

struct KrediEkleView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss
    
    @State private var isim: String = ""
    @State private var cekilenTutarString: String = ""
    @State private var faizOraniString: String = ""
    @State private var faizTipi: FaizTipi = .yillik
    @State private var taksitSayisi: Int = 12
    @State private var ilkTaksitTarihi = Date()
    
    var duzenlenecekHesap: Hesap?

    var body: some View {
         NavigationStack {
            Form {
                Section(header: Text(LocalizedStringKey("loan.form.details_header"))) {
                    TextField(LocalizedStringKey("accounts.add.loan_name_placeholder"), text: $isim)
                    TextField(LocalizedStringKey("accounts.add.loan_amount"), text: $cekilenTutarString).keyboardType(.decimalPad)
                    
                    HStack {
                        TextField(LocalizedStringKey("accounts.add.interest_rate"), text: $faizOraniString).keyboardType(.decimalPad)
                        Picker(LocalizedStringKey("loan.form.interest_type"), selection: $faizTipi) {
                            ForEach(FaizTipi.allCases, id: \.self) { tip in
                                // --- DÜZELTME BURADA ---
                                Text(LocalizedStringKey(tip.localizedKey)).tag(tip)
                            }
                        }.pickerStyle(.menu).labelsHidden()
                    }
                }
                
                Section(header: Text(LocalizedStringKey("accounts.add.installments"))) {
                    Stepper(String.localizedStringWithFormat(NSLocalizedString("accounts.add.installments_stepper", comment: ""), taksitSayisi), value: $taksitSayisi, in: 1...360)
                }
                
                Section(header: Text(LocalizedStringKey("loan.form.first_payment_header"))) {
                     DatePicker(LocalizedStringKey("loan.form.first_installment_date"), selection: $ilkTaksitTarihi, displayedComponents: .date)
                }
            }
            .navigationTitle(duzenlenecekHesap == nil ? LocalizedStringKey("accounts.add.new_loan") : LocalizedStringKey("common.edit"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(LocalizedStringKey("common.cancel"), action: { dismiss() }) }
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("accounts.add.create_installments_button"), action: kaydet)
                        .disabled(isim.isEmpty || cekilenTutarString.isEmpty)
                }
            }
            .onAppear(perform: formuDoldur)
        }
    }
    
    private func formuDoldur() {
        guard let hesap = duzenlenecekHesap, case .kredi(let tutar, let tip, let oran, let sayi, let tarih, _) = hesap.detay else { return }
        isim = hesap.isim
        cekilenTutarString = String(tutar)
        faizOraniString = String(oran)
        faizTipi = tip
        taksitSayisi = sayi
        ilkTaksitTarihi = tarih
    }
    
    private func kaydet() {
        let cekilenTutar = Double(cekilenTutarString.replacingOccurrences(of: ",", with: ".")) ?? 0
        let faizOrani = Double(faizOraniString.replacingOccurrences(of: ",", with: ".")) ?? 0
        let taksitler = taksitleriHesapla(anapara: cekilenTutar, yillikFaizYuzdesi: faizTipi == .yillik ? faizOrani : faizOrani * 12, taksitSayisi: taksitSayisi, ilkOdemeTarihi: ilkTaksitTarihi)
        
        let krediDetayi = HesapDetayi.kredi(cekilenTutar: cekilenTutar, faizTipi: faizTipi, faizOrani: faizOrani, taksitSayisi: taksitSayisi, ilkTaksitTarihi: ilkTaksitTarihi, taksitler: taksitler)
        
        if let hesap = duzenlenecekHesap {
            hesap.isim = isim
            hesap.baslangicBakiyesi = -cekilenTutar
            hesap.detay = krediDetayi
        } else {
            let yeniHesap = Hesap(isim: isim, ikonAdi: "banknote.fill", renkHex: "#5E5CE6", baslangicBakiyesi: -cekilenTutar, detay: krediDetayi)
            modelContext.insert(yeniHesap)
        }
        dismiss()
    }
    
    private func taksitleriHesapla(anapara P: Double, yillikFaizYuzdesi: Double, taksitSayisi n: Int, ilkOdemeTarihi: Date) -> [KrediTaksitDetayi] {
        guard n > 0, P > 0 else { return [] }
        let aylikFaizOrani_r = (yillikFaizYuzdesi / 100) / 12
        let aylikTaksit: Double = aylikFaizOrani_r == 0 ? (P / Double(n)) : (P * (aylikFaizOrani_r * pow(1 + aylikFaizOrani_r, Double(n))) / (pow(1 + aylikFaizOrani_r, Double(n)) - 1))
        var taksitListesi: [KrediTaksitDetayi] = []
        let takvim = Calendar.current
        for i in 0..<n {
            if let odemeGunu = takvim.date(byAdding: .month, value: i, to: ilkTaksitTarihi) {
                taksitListesi.append(KrediTaksitDetayi(taksitTutari: aylikTaksit, odemeTarihi: odemeGunu))
            }
        }
        return taksitListesi
    }
}
