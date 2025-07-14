//
//  AboneliklerRaporView.swift
//  Walleo
//
//  Created by Mustafa Turan on 14.07.2025.
//


import SwiftUI

struct AboneliklerRaporView: View {
    @EnvironmentObject var appSettings: AppSettings
    let veri: AboneliklerVerisi
    
    @State private var secilenKategori: String = "all"
    @State private var genisletilmisGruplar: Set<String> = []
    @State private var hatirlaticiKurulacakAbonelik: TekrarliOdeme?
    @State private var showReminderSuccess = false
    
    private var kategoriler: [String] {
        var cats = Set<String>()
        cats.insert("all")
        veri.abonelikler.forEach { abonelik in
            if let kategori = abonelik.kategori {
                cats.insert(kategori.isim)
            }
        }
        return Array(cats).sorted()
    }
    
    private var filtrelenmisAbonelikler: [TekrarliOdeme] {
        if secilenKategori == "all" {
            return veri.abonelikler
        }
        return veri.abonelikler.filter { $0.kategori?.isim == secilenKategori }
    }
    
    private var gruplanmisAbonelikler: [(kategori: String, abonelikler: [TekrarliOdeme])] {
        Dictionary(grouping: filtrelenmisAbonelikler) { abonelik in
            abonelik.kategori?.isim ?? "reports.subscriptions.uncategorized".localized(appSettings.languageCode)
        }
        .map { (kategori: $0.key, abonelikler: $0.value) }
        .sorted { $0.kategori < $1.kategori }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Özet Kartlar
                ozetKartlar
                
                // Kategori Filtresi
                kategoriFiltresi
                
                // Abonelik Grupları
                abonelikGruplari
                
                // Yaklaşan Ödemeler
                if !veri.yaklasanOdemeler.isEmpty {
                    yaklasanOdemeler
                }
            }
            .padding(.vertical)
        }
        .alert("reports.subscriptions.reminder_set", isPresented: $showReminderSuccess) {
            Button("common.ok", role: .cancel) { }
        } message: {
            Text("reports.subscriptions.reminder_message")
        }
    }
    
    private var ozetKartlar: some View {
        VStack(spacing: 12) {
            // Ana Özet Kartı
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Label("reports.subscriptions.monthly_cost", systemImage: "calendar.circle.fill")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(formatCurrency(
                        amount: veri.aylikToplam,
                        currencyCode: appSettings.currencyCode,
                        localeIdentifier: appSettings.languageCode
                    ))
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.red)
                    
                    Text("reports.subscriptions.count \(veri.abonelikler.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 8) {
                    Text("reports.subscriptions.yearly_projection")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(formatCurrency(
                        amount: veri.yillikProje,
                        currencyCode: appSettings.currencyCode,
                        localeIdentifier: appSettings.languageCode
                    ))
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.orange)
                }
            }
            .padding()
            .background(
                LinearGradient(
                    colors: [Color(.systemGray6), Color(.systemGray6).opacity(0.5)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(12)
            
            // Hızlı İstatistikler
            HStack(spacing: 12) {
                StatCard(
                    title: "reports.subscriptions.most_expensive",
                    value: veri.enPahaliAbonelik?.isim ?? "-",
                    subtitle: veri.enPahaliAbonelik != nil ? formatCurrency(
                        amount: veri.enPahaliAbonelik!.tutar,
                        currencyCode: appSettings.currencyCode,
                        localeIdentifier: appSettings.languageCode
                    ) : nil
                )
                
                StatCard(
                    title: "reports.subscriptions.avg_cost",
                    value: formatCurrency(
                        amount: veri.ortalamaAbonelikTutari,
                        currencyCode: appSettings.currencyCode,
                        localeIdentifier: appSettings.languageCode
                    ),
                    subtitle: nil
                )
            }
        }
        .padding(.horizontal)
    }
    
    private var kategoriFiltresi: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(kategoriler, id: \.self) { kategori in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            secilenKategori = kategori
                        }
                    }) {
                        Text(kategori == "all" ? 
                            LocalizedStringKey("reports.subscriptions.all_categories") : 
                            LocalizedStringKey(kategori)
                        )
                        .font(.caption)
                        .fontWeight(secilenKategori == kategori ? .semibold : .regular)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            secilenKategori == kategori ? 
                            Color.accentColor : Color(.systemGray5)
                        )
                        .foregroundColor(
                            secilenKategori == kategori ? .white : .primary
                        )
                        .cornerRadius(8)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var abonelikGruplari: some View {
        LazyVStack(spacing: 12) {
            ForEach(gruplanmisAbonelikler, id: \.kategori) { grup in
                AbonelikGrupView(
                    kategori: grup.kategori,
                    abonelikler: grup.abonelikler,
                    genisletilmis: genisletilmisGruplar.contains(grup.kategori),
                    onToggle: {
                        withAnimation(.spring()) {
                            if genisletilmisGruplar.contains(grup.kategori) {
                                genisletilmisGruplar.remove(grup.kategori)
                            } else {
                                genisletilmisGruplar.insert(grup.kategori)
                            }
                        }
                    },
                    onReminderTap: { abonelik in
                        hatirlaticiKurulacakAbonelik = abonelik
                        // Gerçek uygulamada burada UNNotification kurulur
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            showReminderSuccess = true
                        }
                    }
                )
            }
        }
        .padding(.horizontal)
    }
    
    private var yaklasanOdemeler: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("reports.subscriptions.upcoming_payments")
                .font(.headline)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(veri.yaklasanOdemeler) { odeme in
                        YaklasanOdemeKart(odeme: odeme)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

struct StatCard: View {
    let title: LocalizedStringKey
    let value: String
    let subtitle: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.callout)
                .fontWeight(.semibold)
                .lineLimit(1)
            
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct AbonelikGrupView: View {
    @EnvironmentObject var appSettings: AppSettings
    let kategori: String
    let abonelikler: [TekrarliOdeme]
    let genisletilmis: Bool
    let onToggle: () -> Void
    let onReminderTap: (TekrarliOdeme) -> Void
    
    private var toplamTutar: Double {
        abonelikler.reduce(0) { $0 + $1.tutar }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Başlık
            Button(action: onToggle) {
                HStack {
                    Image(systemName: genisletilmis ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 20)
                    
                    Text(LocalizedStringKey(kategori))
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("(\(abonelikler.count))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(formatCurrency(
                        amount: toplamTutar,
                        currencyCode: appSettings.currencyCode,
                        localeIdentifier: appSettings.languageCode
                    ))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                }
                .padding()
                .background(Color(.systemGray6))
            }
            .buttonStyle(.plain)
            
            // İçerik
            if genisletilmis {
                VStack(spacing: 8) {
                    ForEach(abonelikler) { abonelik in
                        AbonelikSatir(
                            abonelik: abonelik,
                            onReminderTap: { onReminderTap(abonelik) }
                        )
                    }
                }
                .padding()
                .background(Color(.systemGray6).opacity(0.5))
                .transition(.asymmetric(
                    insertion: .push(from: .top).combined(with: .opacity),
                    removal: .push(from: .bottom).combined(with: .opacity)
                ))
            }
        }
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2)
    }
}

struct AbonelikSatir: View {
    @EnvironmentObject var appSettings: AppSettings
    let abonelik: TekrarliOdeme
    let onReminderTap: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: abonelik.kategori?.ikonAdi ?? "questionmark.circle")
                .font(.title3)
                .foregroundColor(abonelik.kategori?.renk ?? .gray)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(abonelik.isim)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(tekrarText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(formatCurrency(
                amount: abonelik.tutar,
                currencyCode: appSettings.currencyCode,
                localeIdentifier: appSettings.languageCode
            ))
            .font(.subheadline)
            .fontWeight(.semibold)
            
            Button(action: onReminderTap) {
                Image(systemName: "bell")
                    .font(.caption)
                    .foregroundColor(.accentColor)
                    .padding(8)
                    .background(Color.accentColor.opacity(0.1))
                    .clipShape(Circle())
            }
        }
        .padding(.vertical, 4)
    }
    
    private var tekrarText: String {
        switch abonelik.tekrar {
        case .herAy:
            return "reports.subscriptions.frequency.monthly".localized(appSettings.languageCode)
        case .her3Ay:
            return "reports.subscriptions.frequency.quarterly".localized(appSettings.languageCode)
        case .her6Ay:
            return "reports.subscriptions.frequency.semiannually".localized(appSettings.languageCode)
        case .herYil:
            return "reports.subscriptions.frequency.yearly".localized(appSettings.languageCode)
        default:
            return ""
        }
    }
}

struct YaklasanOdemeKart: View {
    @EnvironmentObject var appSettings: AppSettings
    let odeme: YaklasanOdeme
    
    private var gunKaldi: Int {
        Calendar.current.dateComponents([.day], from: Date(), to: odeme.tarih).day ?? 0
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: odeme.kategori?.ikonAdi ?? "questionmark.circle")
                    .font(.title3)
                    .foregroundColor(odeme.kategori?.renk ?? .gray)
                
                Spacer()
                
                Text("\(gunKaldi)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(gunKaldi <= 3 ? .red : .orange)
                + Text(" ")
                + Text("reports.subscriptions.days")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(odeme.isim)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(1)
            
            Text(formatCurrency(
                amount: odeme.tutar,
                currencyCode: appSettings.currencyCode,
                localeIdentifier: appSettings.languageCode
            ))
            .font(.callout)
            .fontWeight(.semibold)
            .foregroundColor(.red)
            
            Text(odeme.tarih.formatted(date: .abbreviated, time: .omitted))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(width: 140)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// String localization extension
extension String {
    func localized(_ languageCode: String) -> String {
        guard let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return self
        }
        return NSLocalizedString(self, bundle: bundle, comment: "")
    }
}