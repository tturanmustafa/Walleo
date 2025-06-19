//
//  TaksitDuzenleView.swift
//  Budgee
//
//  Created by Mustafa Turan on 19.06.2025.
//


// Dosya Adı: TaksitDuzenleView.swift

import SwiftUI

struct TaksitDuzenleView: View {
    @Environment(\.dismiss) var dismiss
    
    // Düzenlenecek taksidin kendisi değil, ID'si ve ana hesap nesnesi ile çalışıyoruz.
    let hesap: Hesap
    let taksitID: UUID
    
    // Form için yerel state'ler
    @State private var tutarString: String = ""
    @State private var odemeTarihi: Date = Date()
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Taksit Bilgileri") {
                    TextField("Tutar", text: $tutarString)
                        .keyboardType(.decimalPad)
                    DatePicker("Ödeme Tarihi", selection: $odemeTarihi, displayedComponents: .date)
                }
            }
            .navigationTitle("Taksiti Düzenle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(LocalizedStringKey("common.cancel")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("common.save"), action: kaydet)
                }
            }
            .onAppear(perform: formuDoldur)
        }
    }
    
    private func formuDoldur() {
        guard case .kredi(_, _, _, _, _, let taksitler) = hesap.detay else { return }
        guard let taksit = taksitler.first(where: { $0.id == taksitID }) else { return }
        
        self.tutarString = String(taksit.taksitTutari)
        self.odemeTarihi = taksit.odemeTarihi
    }
    
    private func kaydet() {
        // Struct'ın içindeki bir değeri değiştirmek için tüm enum'ı yeniden oluşturmalıyız.
        guard case .kredi(let cekilenTutar, let faizTipi, let faizOrani, let taksitSayisi, let ilkTaksitTarihi, var taksitler) = hesap.detay else { return }
        guard let index = taksitler.firstIndex(where: { $0.id == taksitID }) else { return }
        
        let yeniTutar = Double(tutarString.replacingOccurrences(of: ",", with: ".")) ?? 0
        
        // İlgili taksidin değerlerini güncelle
        taksitler[index].taksitTutari = yeniTutar
        taksitler[index].odemeTarihi = odemeTarihi
        
        // Ana hesap nesnesindeki detayı, güncellenmiş taksit listesiyle yeniden ata
        hesap.detay = .kredi(
            cekilenTutar: cekilenTutar,
            faizTipi: faizTipi,
            faizOrani: faizOrani,
            taksitSayisi: taksitSayisi,
            ilkTaksitTarihi: ilkTaksitTarihi,
            taksitler: taksitler
        )
        
        // Değişikliklerin ana listeye yansıması için bildirim gönder
        NotificationCenter.default.post(name: .transactionsDidChange, object: nil)
        dismiss()
    }
}