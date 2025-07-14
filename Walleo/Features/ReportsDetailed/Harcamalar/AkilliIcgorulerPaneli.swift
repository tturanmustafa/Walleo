//
//  AkilliIcgorulerPaneli.swift
//  Walleo
//
//  Created by Mustafa Turan on 15.07.2025.
//


// >> YENİ DOSYA: Features/ReportsDetailed/Views/AkilliIcgorulerPaneli.swift

import SwiftUI

struct AkilliIcgorulerPaneli: View {
    let icgoruler: [HarcamaIcgorusu]
    @EnvironmentObject var appSettings: AppSettings
    
    @State private var gorunurIcgoruIndex = 0
    @State private var otomatikGecisTimer: Timer?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("reports.heatmap.insights")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                // Sayfa göstergeleri
                if icgoruler.count > 1 {
                    HStack(spacing: 6) {
                        ForEach(0..<icgoruler.count, id: \.self) { index in
                            Circle()
                                .fill(index == gorunurIcgoruIndex ? Color.accentColor : Color.gray.opacity(0.3))
                                .frame(width: 6, height: 6)
                                .scaleEffect(index == gorunurIcgoruIndex ? 1.2 : 1.0)
                                .animation(.spring(response: 0.3), value: gorunurIcgoruIndex)
                        }
                    }
                }
            }
            
            // İçgörü içeriği
            if !icgoruler.isEmpty {
                TabView(selection: $gorunurIcgoruIndex) {
                    ForEach(Array(icgoruler.enumerated()), id: \.element.id) { index, icgoru in
                        IcgoruKarti(icgoru: icgoru)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 80)
                .onAppear {
                    baslatOtomatikGecis()
                }
                .onDisappear {
                    durdurOtomatikGecis()
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
    
    private func baslatOtomatikGecis() {
        guard icgoruler.count > 1 else { return }
        
        otomatikGecisTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            withAnimation(.spring(response: 0.5)) {
                gorunurIcgoruIndex = (gorunurIcgoruIndex + 1) % icgoruler.count
            }
        }
    }
    
    private func durdurOtomatikGecis() {
        otomatikGecisTimer?.invalidate()
        otomatikGecisTimer = nil
    }
}

// İçgörü kartı
struct IcgoruKarti: View {
    let icgoru: HarcamaIcgorusu
    @EnvironmentObject var appSettings: AppSettings
    
    var body: some View {
        HStack(spacing: 12) {
            Text(icgoru.ikon)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(formatInsightMessage())
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.tertiarySystemGroupedBackground))
        .cornerRadius(12)
    }
    
    private func formatInsightMessage() -> String {
        let baseMessage = NSLocalizedString(icgoru.mesajKey, comment: "")
        
        // Parametreleri yerine koy
        var formattedMessage = baseMessage
        for (key, value) in icgoru.parametreler {
            let placeholder = "%@"
            if let stringValue = value as? String {
                formattedMessage = formattedMessage.replacingOccurrences(of: placeholder, with: stringValue)
            } else if let intValue = value as? Int {
                formattedMessage = formattedMessage.replacingOccurrences(of: placeholder, with: "\(intValue)")
            } else if let doubleValue = value as? Double {
                formattedMessage = formattedMessage.replacingOccurrences(of: placeholder, with: String(format: "%.1f", doubleValue))
            }
        }
        
        return formattedMessage
    }
}