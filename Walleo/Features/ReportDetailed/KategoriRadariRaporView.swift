//
//  KategoriRadariRaporView.swift
//  Walleo
//
//  Created by Mustafa Turan on 14.07.2025.
//


import SwiftUI
import Charts

struct KategoriRadariRaporView: View {
    @EnvironmentObject var appSettings: AppSettings
    let veri: KategoriRaporVerisi
    
    @State private var secilenTur: IslemTuru = .gider
    @State private var secilenKategori: KategoriAnalizVerisi?
    @State private var hoveredKategori: UUID?
    @State private var showKategoriDetay = false
    @State private var animasyonTamamlandi = false
    
    private var seciliVeriler: [KategoriAnalizVerisi] {
        secilenTur == .gider ? veri.giderKategorileri : veri.gelirKategorileri
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Tür Seçici
                turSecici
                
                // Halka Grafik
                if !seciliVeriler.isEmpty {
                    halkaGrafik
                        .frame(height: 300)
                        .padding(.horizontal)
                } else {
                    ContentUnavailableView(
                        "detailed_reports.category_radar.no_data",
                        systemImage: "chart.pie",
                        description: Text("detailed_reports.category_radar.no_data_desc")
                    )
                    .frame(height: 300)
                }
                
                // Kategori Listesi
                kategoriListesi
            }
            .padding(.vertical)
        }
        .sheet(isPresented: $showKategoriDetay) {
            if let kategori = secilenKategori {
                KategoriDetaySheet(kategori: kategori, tur: secilenTur)
                    .environmentObject(appSettings)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8)) {
                animasyonTamamlandi = true
            }
        }
    }
    
    // MARK: - Tür Seçici
    private var turSecici: some View {
        HStack(spacing: 0) {
            ForEach([IslemTuru.gider, IslemTuru.gelir], id: \.self) { tur in
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        secilenTur = tur
                        secilenKategori = nil
                        hoveredKategori = nil
                    }
                }) {
                    HStack {
                        Image(systemName: tur == .gelir ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                        Text(LocalizedStringKey(tur.rawValue))
                    }
                    .font(.subheadline.bold())
                    .foregroundColor(secilenTur == tur ? .white : .primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        ZStack {
                            if secilenTur == tur {
                                Capsule()
                                    .fill(tur == .gelir ? Color.green : Color.red)
                                    .matchedGeometryEffect(id: "selector", in: animation)
                            }
                        }
                    )
                }
            }
        }
        .background(Color(.secondarySystemBackground))
        .clipShape(Capsule())
        .padding(.horizontal)
    }
    
    @Namespace private var animation
    
    // MARK: - Halka Grafik
    private var halkaGrafik: some View {
        VStack {
            Chart(seciliVeriler) { veri in
                SectorMark(
                    angle: .value("Tutar", animasyonTamamlandi ? veri.tutar : 0),
                    innerRadius: .ratio(0.618),
                    outerRadius: hoveredKategori == veri.id ? .ratio(1.05) : .ratio(1.0),
                    angularInset: 2.0
                )
                .foregroundStyle(veri.kategori.renk)
                .cornerRadius(8)
                .opacity(hoveredKategori == nil || hoveredKategori == veri.id ? 1.0 : 0.5)
            }
            .chartAngleSelection(value: .constant(nil))
            .chartBackground { chartProxy in
                GeometryReader { geometry in
                    let frame = geometry.frame(in: .local)
                    VStack {
                        Text(secilenTur == .gider ? 
                            "detailed_reports.category_radar.total_expense" : 
                            "detailed_reports.category_radar.total_income"
                        )
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        
                        Text(formatCurrency(
                            amount: secilenTur == .gider ? veri.toplamGider : veri.toplamGelir,
                            currencyCode: appSettings.currencyCode,
                            localeIdentifier: appSettings.languageCode
                        ))
                        .font(.title2.bold())
                        .foregroundColor(secilenTur == .gider ? .red : .green)
                    }
                    .position(x: frame.midX, y: frame.midY)
                }
            }
            .overlay(alignment: .topTrailing) {
                if let secilenKategori = secilenKategori {
                    KategoriInfoCard(kategori: secilenKategori, appSettings: appSettings)
                        .padding()
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        // Dokunulan kategoriyi bul
                        if let kategori = findKategoriAtLocation(value.location) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                hoveredKategori = kategori.id
                                secilenKategori = kategori
                            }
                        }
                    }
                    .onEnded { _ in
                        if secilenKategori != nil {
                            showKategoriDetay = true
                        }
                    }
            )
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }
    
    // MARK: - Kategori Listesi
    private var kategoriListesi: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("detailed_reports.category_radar.category_list")
                .font(.headline)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            LazyVStack(spacing: 8) {
                ForEach(seciliVeriler.sorted(by: { $0.tutar > $1.tutar })) { veri in
                    KategoriSatiri(
                        veri: veri,
                        toplamTutar: secilenTur == .gider ? self.veri.toplamGider : self.veri.toplamGelir,
                        appSettings: appSettings,
                        isHighlighted: hoveredKategori == veri.id
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            if secilenKategori?.id == veri.id {
                                secilenKategori = nil
                                hoveredKategori = nil
                            } else {
                                secilenKategori = veri
                                hoveredKategori = veri.id
                            }
                        }
                    }
                    .contextMenu {
                        Button(action: {
                            secilenKategori = veri
                            showKategoriDetay = true
                        }) {
                            Label("detailed_reports.category_radar.view_transactions", 
                                  systemImage: "list.bullet")
                        }
                        
                        Button(action: {
                            // TODO: Bütçe oluşturma ekranına yönlendir
                        }) {
                            Label("detailed_reports.category_radar.create_budget", 
                                  systemImage: "chart.pie")
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Helper Functions
    private func findKategoriAtLocation(_ location: CGPoint) -> KategoriAnalizVerisi? {
        // Basitleştirilmiş kategori bulma - gerçek implementasyonda
        // chart geometrisini kullanarak daha hassas hesaplama yapılmalı
        return seciliVeriler.randomElement()
    }
}

// MARK: - Alt Bileşenler

struct KategoriInfoCard: View {
    let kategori: KategoriAnalizVerisi
    let appSettings: AppSettings
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: kategori.kategori.ikonAdi)
                    .font(.caption)
                    .foregroundColor(kategori.kategori.renk)
                
                Text(LocalizedStringKey(kategori.kategori.localizationKey ?? kategori.kategori.isim))
                    .font(.caption.bold())
            }
            
            Text(formatCurrency(
                amount: kategori.tutar,
                currencyCode: appSettings.currencyCode,
                localeIdentifier: appSettings.languageCode
            ))
            .font(.caption)
            
            Text("\(String(format: "%.1f", kategori.yuzde))%")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(8)
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(radius: 4)
    }
}

struct KategoriSatiri: View {
    let veri: KategoriAnalizVerisi
    let toplamTutar: Double
    let appSettings: AppSettings
    let isHighlighted: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Kategori İkonu
                ZStack {
                    Circle()
                        .fill(veri.kategori.renk.opacity(0.2))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: veri.kategori.ikonAdi)
                        .font(.system(size: 18))
                        .foregroundColor(veri.kategori.renk)
                }
                .scaleEffect(isHighlighted ? 1.1 : 1.0)
                
                // Kategori Bilgileri
                VStack(alignment: .leading, spacing: 4) {
                    Text(LocalizedStringKey(veri.kategori.localizationKey ?? veri.kategori.isim))
                        .font(.subheadline.bold())
                    
                    HStack {
                        Text("\(veri.islemSayisi) \(Text("detailed_reports.category_radar.transactions"))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("detailed_reports.category_radar.avg_amount \(formatCurrency(amount: veri.ortalamaIslem, currencyCode: appSettings.currencyCode, localeIdentifier: appSettings.languageCode))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Tutar ve Yüzde
                VStack(alignment: .trailing, spacing: 4) {
                    Text(formatCurrency(
                        amount: veri.tutar,
                        currencyCode: appSettings.currencyCode,
                        localeIdentifier: appSettings.languageCode
                    ))
                    .font(.subheadline.bold())
                    
                    Text("\(String(format: "%.1f", veri.yuzde))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // İlerleme Göstergesi
                CircularProgressView(progress: veri.yuzde / 100, color: veri.kategori.renk, lineWidth: 3)
                    .frame(width: 30, height: 30)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isHighlighted ? 
                        veri.kategori.renk.opacity(0.1) : 
                        Color(.secondarySystemBackground)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isHighlighted ? veri.kategori.renk : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isHighlighted ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isHighlighted)
    }
}

struct CircularProgressView: View {
    let progress: Double
    let color: Color
    let lineWidth: CGFloat
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.2), lineWidth: lineWidth)
            
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.5), value: progress)
        }
    }
}

struct KategoriDetaySheet: View {
    let kategori: KategoriAnalizVerisi
    let tur: IslemTuru
    @EnvironmentObject var appSettings: AppSettings
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            VStack {
                // Kategori başlığı ve özet
                VStack(spacing: 16) {
                    HStack {
                        Image(systemName: kategori.kategori.ikonAdi)
                            .font(.largeTitle)
                            .foregroundColor(kategori.kategori.renk)
                        
                        VStack(alignment: .leading) {
                            Text(LocalizedStringKey(kategori.kategori.localizationKey ?? kategori.kategori.isim))
                                .font(.title2.bold())
                            
                            Text("\(kategori.islemSayisi) \(Text("detailed_reports.category_radar.transactions"))")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    
                    HStack(spacing: 20) {
                        VStack {
                            Text("detailed_reports.category_radar.total")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(formatCurrency(
                                amount: kategori.tutar,
                                currencyCode: appSettings.currencyCode,
                                localeIdentifier: appSettings.languageCode
                            ))
                            .font(.title3.bold())
                            .foregroundColor(tur == .gelir ? .green : .red)
                        }
                        
                        Divider()
                            .frame(height: 40)
                        
                        VStack {
                            Text("detailed_reports.category_radar.average")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(formatCurrency(
                                amount: kategori.ortalamaIslem,
                                currencyCode: appSettings.currencyCode,
                                localeIdentifier: appSettings.languageCode
                            ))
                            .font(.title3.bold())
                        }
                        
                        Divider()
                            .frame(height: 40)
                        
                        VStack {
                            Text("detailed_reports.category_radar.percentage")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(String(format: "%.1f", kategori.yuzde))%")
                                .font(.title3.bold())
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                }
                .padding()
                
                // TODO: İşlem listesi buraya eklenecek
                Spacer()
                
                Text("detailed_reports.category_radar.transaction_list_placeholder")
                    .foregroundColor(.secondary)
                    .padding()
            }
            .navigationTitle("detailed_reports.category_radar.detail_title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("common.done") { dismiss() }
                }
            }
        }
    }
}