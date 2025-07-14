//
//  FinansalAnlikRaporView.swift
//  Walleo
//
//  Created by Mustafa Turan on 14.07.2025.
//


import SwiftUI
import Charts

struct FinansalAnlikRaporView: View {
    @EnvironmentObject var appSettings: AppSettings
    @ObservedObject var viewModel: DetayliRaporlarViewModel
    @State private var showHedefBelirle = false
    @State private var hedefTutar: Double = 0
    @State private var teraziAnimasyonu = false
    @State private var secilenKefe: TeraziKefe?
    
    enum TeraziKefe {
        case varliklar, borclar
    }
    
    private var finansalAnlik: FinansalAnlikVerisi? {
        viewModel.finansalAnlikVerisi
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let veri = finansalAnlik {
                    // Net Değer Göstergesi
                    NetDegerGostergesi(
                        netDeger: veri.netDeger,
                        hedefDeger: hedefTutar
                    )
                    .padding(.horizontal)
                    .onTapGesture {
                        showHedefBelirle = true
                    }
                    
                    // Animasyonlu Terazi
                    AnimasyonluTerazi(
                        varliklar: veri.toplamVarliklar,
                        borclar: veri.toplamBorclar,
                        animasyon: $teraziAnimasyonu,
                        secilenKefe: $secilenKefe
                    )
                    .frame(height: 250)
                    .padding()
                    
                    // Varlık/Borç Detayları
                    HStack(spacing: 16) {
                        VarlikBorcKarti(
                            baslik: "detailed_reports.snapshot.assets",
                            tutar: veri.toplamVarliklar,
                            hesaplar: veri.varlikHesaplari,
                            renk: .green,
                            tiklaninca: {
                                withAnimation(.spring()) {
                                    secilenKefe = secilenKefe == .varliklar ? nil : .varliklar
                                }
                            }
                        )
                        
                        VarlikBorcKarti(
                            baslik: "detailed_reports.snapshot.liabilities",
                            tutar: veri.toplamBorclar,
                            hesaplar: veri.borcHesaplari,
                            renk: .red,
                            tiklaninca: {
                                withAnimation(.spring()) {
                                    secilenKefe = secilenKefe == .borclar ? nil : .borclar
                                }
                            }
                        )
                    }
                    .padding(.horizontal)
                    
                    // Net Değer Değişim Grafiği
                    NetDegerDegisimGrafigi(
                        veriler: veri.gunlukNetDegerler
                    )
                    .frame(height: 250)
                    .padding()
                    
                    // Finansal Sağlık Göstergeleri
                    FinansalSaglikGostergeleri(
                        borcVarlikOrani: veri.toplamVarliklar > 0 ? veri.toplamBorclar / veri.toplamVarliklar : 0,
                        likiditeDurumu: veri.nakit,
                        aylikGelirGiderOrani: veri.aylikGelirGiderOrani
                    )
                    .padding(.horizontal)
                    
                } else {
                    ProgressView()
                        .frame(height: 400)
                }
            }
            .padding(.vertical)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.0).delay(0.5)) {
                teraziAnimasyonu = true
            }
        }
        .sheet(isPresented: $showHedefBelirle) {
            HedefBelirlemeView(hedefTutar: $hedefTutar)
        }
        .sheet(item: $secilenKefe) { kefe in
            HesapDetayListesi(
                baslik: kefe == .varliklar ? "detailed_reports.snapshot.assets" : "detailed_reports.snapshot.liabilities",
                hesaplar: kefe == .varliklar ? (finansalAnlik?.varlikHesaplari ?? []) : (finansalAnlik?.borcHesaplari ?? [])
            )
        }
    }
}

// Net Değer Göstergesi
struct NetDegerGostergesi: View {
    @EnvironmentObject var appSettings: AppSettings
    let netDeger: Double
    let hedefDeger: Double
    
    @State private var animatedValue: Double = 0
    @State private var showConfetti = false
    
    private var hedefYuzde: Double {
        guard hedefDeger > 0 else { return 0 }
        return min((netDeger / hedefDeger) * 100, 100)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Text("detailed_reports.snapshot.net_worth")
                .font(.headline)
            
            ZStack {
                // Arka plan gradyanı
                LinearGradient(
                    colors: [
                        netDeger >= 0 ? Color.green.opacity(0.3) : Color.red.opacity(0.3),
                        Color.clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                
                VStack(spacing: 8) {
                    Text(formatCurrency(
                        amount: animatedValue,
                        currencyCode: appSettings.currencyCode,
                        localeIdentifier: appSettings.languageCode
                    ))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(netDeger >= 0 ? .green : .red)
                    
                    if hedefDeger > 0 {
                        HStack {
                            Text("detailed_reports.snapshot.goal_progress")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("\(Int(hedefYuzde))%")
                                .font(.caption.bold())
                                .foregroundColor(.accentColor)
                        }
                        
                        ProgressView(value: hedefYuzde, total: 100)
                            .tint(.accentColor)
                            .scaleEffect(x: 1, y: 2)
                            .padding(.horizontal)
                    } else {
                        Text("detailed_reports.snapshot.tap_to_set_goal")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                
                if showConfetti {
                    ConfettiView()
                }
            }
            .frame(height: 150)
            .cornerRadius(20)
            .shadow(color: .black.opacity(0.1), radius: 10)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.2)) {
                animatedValue = netDeger
            }
            
            if hedefDeger > 0 && netDeger >= hedefDeger {
                showConfetti = true
            }
        }
    }
}

// Animasyonlu Terazi
struct AnimasyonluTerazi: View {
    let varliklar: Double
    let borclar: Double
    @Binding var animasyon: Bool
    @Binding var secilenKefe: TeraziKefe?
    
    private var dengeAcisi: Double {
        let fark = varliklar - borclar
        let maxFark = max(varliklar, borclar)
        guard maxFark > 0 else { return 0 }
        
        let oran = fark / maxFark
        return oran * 15 // Maksimum 15 derece eğim
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Terazi gövdesi
                TeraziGovdesi()
                
                // Sol kefe (Varlıklar)
                TeraziKefesi(
                    tutar: varliklar,
                    renk: .green,
                    etiket: "detailed_reports.snapshot.assets",
                    aci: animasyon ? -dengeAcisi : 0,
                    yukariKayma: animasyon ? dengeAcisi * 2 : 0,
                    secili: secilenKefe == .varliklar
                )
                .position(
                    x: geometry.size.width * 0.25,
                    y: geometry.size.height * 0.5
                )
                .onTapGesture {
                    withAnimation(.spring()) {
                        secilenKefe = secilenKefe == .varliklar ? nil : .varliklar
                    }
                }
                
                // Sağ kefe (Borçlar)
                TeraziKefesi(
                    tutar: borclar,
                    renk: .red,
                    etiket: "detailed_reports.snapshot.liabilities",
                    aci: animasyon ? -dengeAcisi : 0,
                    yukariKayma: animasyon ? -dengeAcisi * 2 : 0,
                    secili: secilenKefe == .borclar
                )
                .position(
                    x: geometry.size.width * 0.75,
                    y: geometry.size.height * 0.5
                )
                .onTapGesture {
                    withAnimation(.spring()) {
                        secilenKefe = secilenKefe == .borclar ? nil : .borclar
                    }
                }
                
                // Terazi kolu
                Rectangle()
                    .fill(Color.primary.opacity(0.3))
                    .frame(width: geometry.size.width * 0.6, height: 4)
                    .position(
                        x: geometry.size.width * 0.5,
                        y: geometry.size.height * 0.5
                    )
                    .rotationEffect(.degrees(animasyon ? dengeAcisi : 0))
            }
        }
    }
}

// Terazi Kefesi
struct TeraziKefesi: View {
    @EnvironmentObject var appSettings: AppSettings
    let tutar: Double
    let renk: Color
    let etiket: LocalizedStringKey
    let aci: Double
    let yukariKayma: Double
    let secili: Bool
    
    @State private var hover = false
    
    var body: some View {
        VStack(spacing: 8) {
            // İp
            Rectangle()
                .fill(Color.gray.opacity(0.5))
                .frame(width: 2, height: 40)
                .offset(y: -yukariKayma)
            
            // Kefe
            ZStack {
                Circle()
                    .fill(renk.opacity(0.2))
                    .frame(width: 100, height: 100)
                    .scaleEffect(secili ? 1.2 : (hover ? 1.1 : 1.0))
                    .shadow(color: renk.opacity(0.3), radius: secili ? 15 : 5)
                
                VStack(spacing: 4) {
                    Text(etiket)
                        .font(.caption.bold())
                    
                    Text(formatCurrency(
                        amount: tutar,
                        currencyCode: appSettings.currencyCode,
                        localeIdentifier: appSettings.languageCode
                    ))
                    .font(.caption)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                }
                .foregroundColor(renk)
            }
            .offset(y: -yukariKayma)
        }
        .rotationEffect(.degrees(aci))
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                hover = hovering
            }
        }
    }
}

// Terazi Gövdesi
struct TeraziGovdesi: View {
    var body: some View {
        VStack(spacing: 0) {
            // Üçgen destek
            Triangle()
                .fill(Color.primary.opacity(0.3))
                .frame(width: 60, height: 40)
                .offset(y: 80)
            
            // Taban
            Rectangle()
                .fill(Color.primary.opacity(0.2))
                .frame(width: 120, height: 8)
                .cornerRadius(4)
                .offset(y: 80)
        }
    }
}

// Üçgen şekli
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// Varlık/Borç Kartı
struct VarlikBorcKarti: View {
    @EnvironmentObject var appSettings: AppSettings
    let baslik: LocalizedStringKey
    let tutar: Double
    let hesaplar: [HesapOzeti]
    let renk: Color
    let tiklaninca: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(baslik)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(formatCurrency(
                amount: tutar,
                currencyCode: appSettings.currencyCode,
                localeIdentifier: appSettings.languageCode
            ))
            .font(.title3.bold())
            .foregroundColor(renk)
            
            Text("\(hesaplar.count) \(NSLocalizedString("detailed_reports.snapshot.accounts", comment: ""))")
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Mini gösterge
            if !hesaplar.isEmpty {
                VStack(spacing: 2) {
                    ForEach(hesaplar.prefix(3)) { hesap in
                        HStack {
                            Circle()
                                .fill(renk.opacity(0.3))
                                .frame(width: 4, height: 4)
                            
                            Text(hesap.isim)
                                .font(.caption2)
                                .lineLimit(1)
                            
                            Spacer()
                        }
                    }
                    
                    if hesaplar.count > 3 {
                        Text("detailed_reports.snapshot.and_more \(hesaplar.count - 3)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5)
        .onTapGesture(perform: tiklaninca)
    }
}

// Net Değer Değişim Grafiği
struct NetDegerDegisimGrafigi: View {
    let veriler: [NetDegerVeri]
    @State private var secilenNokta: NetDegerVeri?
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("detailed_reports.snapshot.net_worth_trend")
                .font(.headline)
                .padding(.horizontal)
            
            if !veriler.isEmpty {
                Chart(veriler) { veri in
                    LineMark(
                        x: .value("Tarih", veri.tarih),
                        y: .value("Net Değer", veri.netDeger)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.green, .blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .lineStyle(StrokeStyle(lineWidth: 3))
                    
                    AreaMark(
                        x: .value("Tarih", veri.tarih),
                        y: .value("Net Değer", veri.netDeger)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.green.opacity(0.2), .blue.opacity(0.1)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    
                    if secilenNokta?.id == veri.id {
                        PointMark(
                            x: .value("Tarih", veri.tarih),
                            y: .value("Net Değer", veri.netDeger)
                        )
                        .foregroundStyle(.blue)
                        .symbolSize(100)
                    }
                }
                .chartXAxis {
                    AxisMarks(preset: .aligned)
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .chartOverlay { proxy in
                    GeometryReader { geometry in
                        Rectangle()
                            .fill(.clear)
                            .contentShape(Rectangle())
                            .onTapGesture { location in
                                // Tıklanan noktayı bul
                                let xPosition = location.x
                                let plotFrame = geometry.frame(in: .local)
                                let xValue = proxy.value(atX: xPosition, as: Date.self)
                                
                                if let date = xValue,
                                   let closest = veriler.min(by: { abs($0.tarih.timeIntervalSince(date)) < abs($1.tarih.timeIntervalSince(date)) }) {
                                    withAnimation {
                                        secilenNokta = secilenNokta?.id == closest.id ? nil : closest
                                    }
                                }
                            }
                    }
                }
            } else {
                Text("detailed_reports.no_data")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            }
        }
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// Finansal Sağlık Göstergeleri
struct FinansalSaglikGostergeleri: View {
    let borcVarlikOrani: Double
    let likiditeDurumu: Double
    let aylikGelirGiderOrani: Double
    
    var body: some View {
        VStack(spacing: 16) {
            Text("detailed_reports.snapshot.financial_health")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 16) {
                SaglikGostergesi(
                    baslik: "detailed_reports.snapshot.debt_ratio",
                    deger: borcVarlikOrani,
                    tip: .yuzde,
                    iyiAralik: 0...0.5
                )
                
                SaglikGostergesi(
                    baslik: "detailed_reports.snapshot.liquidity",
                    deger: likiditeDurumu,
                    tip: .para,
                    iyiAralik: 10000...Double.infinity
                )
                
                SaglikGostergesi(
                    baslik: "detailed_reports.snapshot.income_expense_ratio",
                    deger: aylikGelirGiderOrani,
                    tip: .oran,
                    iyiAralik: 1.2...Double.infinity
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// Sağlık Göstergesi Komponenti
struct SaglikGostergesi: View {
    @EnvironmentObject var appSettings: AppSettings
    let baslik: LocalizedStringKey
    let deger: Double
    let tip: GostergeTipi
    let iyiAralik: ClosedRange<Double>
    
    enum GostergeTipi {
        case yuzde, para, oran
    }
    
    private var durum: SaglikDurumu {
        if iyiAralik.contains(deger) { return .iyi }
        
        let altSinir = iyiAralik.lowerBound
        let ustSinir = iyiAralik.upperBound
        
        if deger < altSinir {
            let fark = altSinir - deger
            return fark < altSinir * 0.2 ? .orta : .kotu
        } else {
            let fark = deger - ustSinir
            return fark < ustSinir * 0.2 ? .orta : .kotu
        }
    }
    
    enum SaglikDurumu {
        case iyi, orta, kotu
        
        var renk: Color {
            switch self {
            case .iyi: return .green
            case .orta: return .orange
            case .kotu: return .red
            }
        }
        
        var ikon: String {
            switch self {
            case .iyi: return "checkmark.circle.fill"
            case .orta: return "exclamationmark.triangle.fill"
            case .kotu: return "xmark.circle.fill"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: durum.ikon)
                .font(.title2)
                .foregroundColor(durum.renk)
            
            Text(baslik)
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Text(formatDeger())
                .font(.caption.bold())
                .foregroundColor(durum.renk)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(durum.renk.opacity(0.1))
        .cornerRadius(8)
    }
    
    private func formatDeger() -> String {
        switch tip {
        case .yuzde:
            return String(format: "%.1f%%", deger * 100)
        case .para:
            return formatCurrency(
                amount: deger,
                currencyCode: appSettings.currencyCode,
                localeIdentifier: appSettings.languageCode
            )
        case .oran:
            return String(format: "%.2fx", deger)
        }
    }
}

// Hedef Belirleme View
struct HedefBelirlemeView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appSettings: AppSettings
    @Binding var hedefTutar: Double
    @State private var girilenTutar = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("detailed_reports.snapshot.set_goal_description")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
                
                VStack(alignment: .leading) {
                    Text("detailed_reports.snapshot.goal_amount")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextField("0", text: $girilenTutar)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                        .font(.title)
                }
                .padding(.horizontal)
                
                // Hızlı seçim butonları
                HStack(spacing: 12) {
                    ForEach([100000, 250000, 500000, 1000000], id: \.self) { tutar in
                        Button(action: {
                            girilenTutar = String(tutar)
                        }) {
                            Text(formatCurrency(
                                amount: Double(tutar),
                                currencyCode: appSettings.currencyCode,
                                localeIdentifier: appSettings.languageCode
                            ))
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(.systemGray5))
                            .cornerRadius(8)
                        }
                    }
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationTitle("detailed_reports.snapshot.set_goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save") {
                        if let tutar = Double(girilenTutar) {
                            hedefTutar = tutar
                            // UserDefaults'a kaydet
                            UserDefaults.standard.set(tutar, forKey: "netDegerHedefi")
                        }
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            if hedefTutar > 0 {
                girilenTutar = String(Int(hedefTutar))
            }
        }
    }
}

// Hesap Detay Listesi
struct HesapDetayListesi: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appSettings: AppSettings
    let baslik: LocalizedStringKey
    let hesaplar: [HesapOzeti]
    
    var body: some View {
        NavigationStack {
            List(hesaplar) { hesap in
                HStack {
                    Image(systemName: hesap.ikon)
                        .font(.title3)
                        .foregroundColor(hesap.renk)
                        .frame(width: 30)
                    
                    VStack(alignment: .leading) {
                        Text(hesap.isim)
                            .font(.subheadline)
                        
                        Text(hesap.tur)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text(formatCurrency(
                        amount: hesap.bakiye,
                        currencyCode: appSettings.currencyCode,
                        localeIdentifier: appSettings.languageCode
                    ))
                    .font(.subheadline.bold())
                    .foregroundColor(hesap.bakiye >= 0 ? .primary : .red)
                }
                .padding(.vertical, 4)
            }
            .navigationTitle(baslik)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.done") { dismiss() }
                }
            }
        }
    }
}

// Confetti View (Hedef başarıldığında)
struct ConfettiView: View {
    @State private var animate = false
    
    var body: some View {
        ZStack {
            ForEach(0..<50) { _ in
                ConfettiPiece()
                    .offset(y: animate ? 600 : -50)
                    .animation(
                        Animation.linear(duration: Double.random(in: 2...3))
                            .repeatForever(autoreverses: false)
                            .delay(Double.random(in: 0...1)),
                        value: animate
                    )
            }
        }
        .onAppear {
            animate = true
        }
    }
}

struct ConfettiPiece: View {
    @State private var rotation = Double.random(in: 0...360)
    let color = [Color.red, .blue, .green, .yellow, .purple, .orange].randomElement()!
    let size = CGFloat.random(in: 5...15)
    let xPosition = CGFloat.random(in: -200...200)
    
    var body: some View {
        Rectangle()
            .fill(color)
            .frame(width: size, height: size)
            .rotationEffect(.degrees(rotation))
            .position(x: xPosition, y: 0)
            .onAppear {
                withAnimation(
                    Animation.linear(duration: Double.random(in: 2...3))
                        .repeatForever(autoreverses: false)
                ) {
                    rotation += 360
                }
            }
    }
}