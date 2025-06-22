// Dosya Adı: TaksitDuzenleView.swift (NİHAİ - HANE KONTROLLÜ)

import SwiftUI

struct TaksitDuzenleView: View {
    @Environment(\.dismiss) var dismiss
    
    let hesap: Hesap
    let taksitID: UUID
    
    @State private var tutarString: String = ""
    @State private var odemeTarihi: Date = Date()
    
    // YENİ: Tutar alanı için doğrulama durumu
    @State private var isTutarGecersiz = false
    
    // YENİ: Form geçerliliği kontrolü
    private var isFormValid: Bool {
        !tutarString.isEmpty && !isTutarGecersiz
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(LocalizedStringKey("installment.edit.details_header")) {
                    VStack(alignment: .leading) {
                        TextField(LocalizedStringKey("common.amount"), text: $tutarString)
                            .keyboardType(.decimalPad)
                            .validateAmountInput(text: $tutarString, isInvalid: $isTutarGecersiz) // Değişiklik burada
                            .overlay(RoundedRectangle(cornerRadius: 5).stroke(isTutarGecersiz ? .red : .clear, lineWidth: 1))
                        
                        if isTutarGecersiz {
                            Text(LocalizedStringKey("validation.error.invalid_amount_format"))
                                .font(.caption).foregroundColor(.red).padding(.top, 2)
                        }
                    }
                    DatePicker(LocalizedStringKey("common.date"), selection: $odemeTarihi, displayedComponents: .date)
                }
            }
            .navigationTitle(LocalizedStringKey("installment.edit.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(LocalizedStringKey("common.cancel")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("common.save"), action: kaydet)
                        .disabled(!isFormValid) // GÜNCELLENDİ
                }
            }
            .onAppear(perform: formuDoldur)
        }
    }
    
    private func haneKontrolluDogrula(newValue: String) {
        if newValue.isEmpty { isTutarGecersiz = false; return }
        let normalizedString = newValue.replacingOccurrences(of: ",", with: ".")
        guard normalizedString.components(separatedBy: ".").count <= 2, Double(normalizedString) != nil else { isTutarGecersiz = true; return }
        let parts = normalizedString.components(separatedBy: ".")
        if parts[0].count > 9 { isTutarGecersiz = true; return }
        if parts.count == 2 && parts[1].count > 2 { isTutarGecersiz = true; return }
        isTutarGecersiz = false
    }
    
    private func formuDoldur() {
        guard case .kredi(_, _, _, _, _, let taksitler) = hesap.detay,
              let taksit = taksitler.first(where: { $0.id == taksitID }) else { return }
        
        tutarString = String(format: "%.2f", taksit.taksitTutari).replacingOccurrences(of: ".", with: ",")
        haneKontrolluDogrula(newValue: tutarString) // GÜNCELLENDİ
        odemeTarihi = taksit.odemeTarihi
    }
    
    private func kaydet() {
        guard case .kredi(let cekilenTutar, let faizTipi, let faizOrani, let taksitSayisi, let ilkTaksitTarihi, var taksitler) = hesap.detay else { return }
        guard let index = taksitler.firstIndex(where: { $0.id == taksitID }) else { return }
        
        let yeniTutar = Double(tutarString.replacingOccurrences(of: ",", with: ".")) ?? 0
        
        taksitler[index].taksitTutari = yeniTutar
        taksitler[index].odemeTarihi = odemeTarihi
        
        hesap.detay = .kredi(
            cekilenTutar: cekilenTutar,
            faizTipi: faizTipi,
            faizOrani: faizOrani,
            taksitSayisi: taksitSayisi,
            ilkTaksitTarihi: ilkTaksitTarihi,
            taksitler: taksitler
        )
        
        NotificationCenter.default.post(name: .transactionsDidChange, object: nil)
        dismiss()
    }
}
