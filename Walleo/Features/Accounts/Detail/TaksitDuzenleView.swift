import SwiftUI

struct TaksitDuzenleView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appSettings: AppSettings
    
    let hesap: Hesap
    let taksitID: UUID
    
    @State private var tutarString: String = ""
    @State private var odemeTarihi: Date = Date()
    
    @State private var isTutarGecersiz = false
    
    private var isFormValid: Bool {
        !tutarString.isEmpty && !isTutarGecersiz
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(LocalizedStringKey("installment.edit.details_header")) {
                    // TUTAR ALANI
                    LabeledAmountField(
                        label: "form.label.amount",
                        placeholder: "common.amount", // Genel bir placeholder
                        valueString: $tutarString,
                        isInvalid: $isTutarGecersiz,
                        locale: Locale(identifier: appSettings.languageCode)
                    )

                    DatePicker(LocalizedStringKey("common.date"), selection: $odemeTarihi, displayedComponents: .date)
                }
            }            .navigationTitle(LocalizedStringKey("installment.edit.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(LocalizedStringKey("common.cancel")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("common.save"), action: kaydet)
                        .disabled(!isFormValid)
                }
            }
            .onAppear(perform: formuDoldur)
        }
    }
    
    private func formuDoldur() {
        guard case .kredi(_, _, _, _, _, let taksitler) = hesap.detay,
              let taksit = taksitler.first(where: { $0.id == taksitID }) else { return }
        
        tutarString = formatAmountForEditing(amount: taksit.taksitTutari, localeIdentifier: appSettings.languageCode)
        isTutarGecersiz = false
        odemeTarihi = taksit.odemeTarihi
    }
    
    private func kaydet() {
        guard case .kredi(let cekilenTutar, let faizTipi, let faizOrani, let taksitSayisi, let ilkTaksitTarihi, var taksitler) = hesap.detay else { return }
        guard let index = taksitler.firstIndex(where: { $0.id == taksitID }) else { return }
        
        let yeniTutar = stringToDouble(tutarString, locale: Locale(identifier: appSettings.languageCode))
        
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
