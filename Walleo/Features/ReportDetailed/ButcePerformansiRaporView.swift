//
//  ButcePerformansiRaporView.swift
//  Walleo
//
//  Created by Mustafa Turan on 14.07.2025.
//


import SwiftUI

struct ButcePerformansiRaporView: View {
    @EnvironmentObject var appSettings: AppSettings
    let veri: ButcePerformansiVerisi
    
    @State private var secilenFiltre: ButceFiltresi = .tumu
    @State private var siralama: ButceSiralama = .varsayilan
    @State private var draggedBudget: Butce?
    
    enum ButceFiltresi: String, CaseIterable {
        case tumu = "all"
        case limitiAsanlar = "over_limit"
        case riskli = "risky"
        
        var localizedKey: LocalizedStringKey {
            switch self {
            case .tumu: return "reports.budget.filter.all"
            case .limitiAsanlar: return "reports.budget.filter.over_limit"
            case .riskli: return "reports.budget.filter.risky"
            }
        }
    }
    
    enum ButceSiralama: String, CaseIterable {
        case varsayilan = "default"
        case adaGore = "name"
        case tutaraGore = "amount"
        case oranaGore = "percentage"
        
        var localizedKey: LocalizedStringKey {
            switch self {
            case .varsayilan: return "reports.budget.sort.default"
            case .adaGore: return "reports.budget.sort.name"
            case .tutaraGore: return "reports.budget.sort.amount"
            case .oranaGore: return "reports.budget.sort.percentage"
            }
        }
    }
    
    private var filtrelenmisButceler: [ButcePerformansi] {
        let filtered = veri.butceler.filter { butce in
            switch secilenFiltre {
            case .tumu:
                return true
            case .limitiAsanlar:
                return butce.harcanan > butce.limit
            case .riskli:
                return butce.limit > 0 && (butce.harcanan / butce.limit) >= 0.8
            }
        }
        
        switch siralama {
        case .varsayilan:
            return filtered
        case .adaGore:
            return filtered.sorted { $0.butce.isim < $1.butce.isim }
        case .tutaraGore:
            return filtered.sorted { $0.harcanan > $1.harcanan }
        case .oranaGore:
            return filtered.sorted { 
                let oran1 = $0.limit > 0 ? $0.harcanan / $0.limit : 0
                let oran2 = $1.limit > 0 ? $1.harcanan / $1.limit : 0
                return oran1 > oran2
            }
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Genel Durum Özeti
                genelDurumOzeti
                
                // Filtre ve Sıralama
                filtreVeSiralama
                
                // Bütçe Kartları
                butceKartlari
            }
            .padding(.vertical)
        }
    }
    
    private var genelDurumOzeti: some View {
        VStack(spacing: 16) {
            Text("reports.budget.overall_status")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 16) {
                // Toplam Limit
                VStack(alignment: .leading, spacing: 4) {
                    Label("reports.budget.total_limit", systemImage: "target")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(formatCurrency(
                        amount: veri.toplamLimit,
                        currencyCode: appSettings.currencyCode,
                        localeIdentifier: appSettings.languageCode
                    ))
                    .font(.title3)
                    .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Toplam Harcama
                VStack(alignment: .leading, spacing: 4) {
                    Label("reports.budget.total_spent", systemImage: "cart")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(formatCurrency(
                        amount: veri.toplamHarcama,
                        currencyCode: appSettings.currencyCode,
                        localeIdentifier: appSettings.languageCode
                    ))
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(veri.toplamHarcama > veri.toplamLimit ? .red : .primary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            // Genel İlerleme
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("reports.budget.overall_usage")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(Int((veri.toplamHarcama / max(veri.toplamLimit, 1)) * 100))%")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(.systemGray5))
                            .frame(height: 8)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(progressColor(for: veri.toplamHarcama / max(veri.toplamLimit, 1)))
                            .frame(
                                width: min(
                                    CGFloat(veri.toplamHarcama / max(veri.toplamLimit, 1)) * geometry.size.width,
                                    geometry.size.width
                                ),
                                height: 8
                            )
                            .animation(.spring(), value: veri.toplamHarcama)
                    }
                }
                .frame(height: 8)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    private var filtreVeSiralama: some View {
        VStack(spacing: 12) {
            // Filtre Butonları
            HStack(spacing: 8) {
                ForEach(ButceFiltresi.allCases, id: \.self) { filtre in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            secilenFiltre = filtre
                        }
                    }) {
                        Text(filtre.localizedKey)
                            .font(.caption)
                            .fontWeight(secilenFiltre == filtre ? .semibold : .regular)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(secilenFiltre == filtre ? Color.accentColor : Color(.systemGray5))
                            .foregroundColor(secilenFiltre == filtre ? .white : .primary)
                            .cornerRadius(8)
                    }
                }
                
                Spacer()
            }
            
            // Sıralama Seçici
            HStack {
                Text("reports.budget.sort_by")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Picker("", selection: $siralama) {
                    ForEach(ButceSiralama.allCases, id: \.self) { siralama in
                        Text(siralama.localizedKey).tag(siralama)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                
                Spacer()
            }
        }
        .padding(.horizontal)
    }
    
    private var butceKartlari: some View {
        LazyVStack(spacing: 12) {
            ForEach(filtrelenmisButceler) { performans in
                DraggableButceKart(performans: performans)
                    .padding(.horizontal)
                    .transition(.asymmetric(
                        insertion: .scale.combined(with: .opacity),
                        removal: .scale.combined(with: .opacity)
                    ))
            }
        }
        .animation(.spring(), value: filtrelenmisButceler.map { $0.id })
    }
    
    private func progressColor(for percentage: Double) -> Color {
        if percentage >= 1.0 { return .red }
        if percentage >= 0.8 { return .orange }
        return .green
    }
}

struct DraggableButceKart: View {
    @EnvironmentObject var appSettings: AppSettings
    let performans: ButcePerformansi
    @State private var isDragging = false
    
    private var yuzde: Double {
        performans.limit > 0 ? performans.harcanan / performans.limit : 0
    }
    
    private var kalanTutar: Double {
        performans.limit - performans.harcanan
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Başlık ve Menü
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(performans.butce.isim)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    if let kategoriler = performans.butce.kategoriler, !kategoriler.isEmpty {
                        Text(kategoriler.prefix(3).map { 
                            LocalizedStringKey(kategori.localizationKey ?? kategori.isim).stringValue(locale: Locale(identifier: appSettings.languageCode))
                        }.joined(separator: ", "))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    }
                }
                
                Spacer()
                
                // Durum İkonu
                Image(systemName: statusIcon)
                    .font(.title2)
                    .foregroundColor(statusColor)
            }
            
            // İlerleme Çubuğu
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(.systemGray5))
                    
                    RoundedRectangle(cornerRadius: 6)
                        .fill(statusColor)
                        .frame(width: min(CGFloat(yuzde) * geometry.size.width, geometry.size.width))
                        .animation(.spring(), value: yuzde)
                }
            }
            .frame(height: 12)
            
            // Detaylar
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("reports.budget.spent")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(formatCurrency(
                        amount: performans.harcanan,
                        currencyCode: appSettings.currencyCode,
                        localeIdentifier: appSettings.languageCode
                    ))
                    .font(.callout)
                    .fontWeight(.semibold)
                    .foregroundColor(statusColor)
                }
                
                Spacer()
                
                VStack(alignment: .center, spacing: 4) {
                    Text("\(Int(yuzde * 100))%")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(statusColor)
                    
                    Text("reports.budget.used")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("reports.budget.remaining")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(formatCurrency(
                        amount: kalanTutar,
                        currencyCode: appSettings.currencyCode,
                        localeIdentifier: appSettings.languageCode
                    ))
                    .font(.callout)
                    .fontWeight(.semibold)
                    .foregroundColor(kalanTutar < 0 ? .red : .primary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(isDragging ? 0.2 : 0.1), radius: isDragging ? 10 : 5)
        .scaleEffect(isDragging ? 1.05 : 1.0)
        .animation(.spring(), value: isDragging)
        .draggable(performans) {
            DraggableButceKart(performans: performans)
                .environmentObject(appSettings)
                .onAppear { isDragging = true }
                .onDisappear { isDragging = false }
        }
    }
    
    private var statusIcon: String {
        if yuzde >= 1.0 { return "exclamationmark.circle.fill" }
        if yuzde >= 0.8 { return "exclamationmark.triangle.fill" }
        return "checkmark.circle.fill"
    }
    
    private var statusColor: Color {
        if yuzde >= 1.0 { return .red }
        if yuzde >= 0.8 { return .orange }
        return .green
    }
}

// LocalizedStringKey extension for getting string value
extension LocalizedStringKey {
    func stringValue(locale: Locale) -> String {
        let mirror = Mirror(reflecting: self)
        if let key = mirror.children.first?.value as? String {
            return NSLocalizedString(key, bundle: .main, comment: "")
        }
        return ""
    }
}