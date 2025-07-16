//
//  DonemNavigatorView.swift
//  Walleo
//
//  Created by Mustafa Turan on 16.07.2025.
//


import SwiftUI

struct DonemNavigatorView: View {
    @EnvironmentObject var appSettings: AppSettings
    
    // Görüntülenecek tarih aralığı
    let baslangicTarihi: Date
    let bitisTarihi: Date
    
    // Butonların eylemleri
    let onOnceki: () -> Void
    let onSonraki: () -> Void

    private var donemYazisi: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: appSettings.languageCode)
        formatter.dateFormat = "d MMM" // Örn: "16 Tem"
        
        let baslangicStr = formatter.string(from: baslangicTarihi)
        let bitisStr = formatter.string(from: bitisTarihi)
        
        return "\(baslangicStr) - \(bitisStr)"
    }

    var body: some View {
        HStack {
            Button(action: onOnceki) { Image(systemName: "chevron.left") }
            Spacer()
            Text(donemYazisi)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            Spacer()
            Button(action: onSonraki) { Image(systemName: "chevron.right") }
        }
        .font(.title3)
        .foregroundColor(.secondary)
        .padding(.horizontal, 30)
        .padding(.top)
    }
}