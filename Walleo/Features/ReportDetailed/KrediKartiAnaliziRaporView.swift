//
//  KrediKartiAnaliziRaporView.swift
//  Walleo
//
//  Created by Mustafa Turan on 14.07.2025.
//


// Dosya: /Users/mt/Documents/GitHub/Walleo/Walleo/Features/ReportDetailed/KrediKartiAnaliziRaporView.swift

import SwiftUI
import Charts

struct KrediKartiAnaliziRaporView: View {
    @EnvironmentObject var appSettings: AppSettings
    let veri: KrediKartiAnaliziVerisi
    
    @State private var secilenKart: Hesap?
    @State private var kartDonuyor = false
    @State private var animasyonTamamlandi = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Başlık
                baslikView
                
                // Kart Seçici
                kartSecici
                
                // 3D Kart Görünümü
                if let kart = secilenKart ?? veri.kartlar.first {
                    ucBoyutluKartView(kart: kart)
                }
                
                // Limit ve Borç Göstergesi
                limitBorcGostergesi
                
                // Harcama Dağılımı
                harcamaDagilimi
            }
            .padding()
        }
        .onAppear {
            secilenKart = veri.kartlar.first
            withAnimation(.easeOut(duration: 0.8)) {
                animasyonTamamlandi = true
            }
        }
    }
    
    private var baslikView: some View {
        HStack {
            Image(systemName: "creditcard.fill")
                .font(.title2)
                .foregroundColor(.purple)
            
            Text("detailed_reports.credit_card_analysis.title")
                .font(.title2.bold())
            
            Spacer()
        }
        .padding(.bottom, 10)
    }
    
    private var kartSecici: some View {
        Group {
            if veri.kartlar.count > 1 {
                Picker("detailed_reports.credit_card_analysis.card_picker", selection: $secilenKart) {
                    Text("detailed_reports.credit_card_analysis.all_cards")
                        .tag(nil as Hesap?)
                    
                    ForEach(veri.kartlar, id: \.id) { kart in
                        Text(kart.isim)
                            .tag(kart as Hesap?)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
            }
        }
    }
    
    private func ucBoyutluKartView(kart: Hesap) -> some View {
        VStack {
            ZStack {
                // Kart arka planı
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [kart.renk, kart.renk.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 300, height: 180)
                    .shadow(color: .black.opacity(0.3), radius: 10, y: 5)
                
                // Kart içeriği
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Image(systemName: "creditcard.fill")
                            .font(.title)
                            .foregroundColor(.white.opacity(0.8))
                        
                        Spacer()
                        
                        Text("VISA")
                            .font(.title2.bold())
                            .foregroundColor(.white)
                    }
                    
                    Text("•••• •••• •••• \(String(kart.id.uuidString.suffix(4)))")
                        .font(.title3)
                        .foregroundColor(.white)
                        .kerning(2)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("detailed_reports.credit_card_analysis.card_holder")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                        
                        Text(kart.isim.uppercased())
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                    }
                }
                .padding()
            }
            .rotation3DEffect(
                .degrees(kartDonuyor ? 180 : 0),
                axis: (x: 0, y: 1, z: 0)
            )
            .onTapGesture {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    kartDonuyor.toggle()
                }
            }
        }
        .padding(.vertical)
        .scaleEffect(animasyonTamamlandi ? 1 : 0.8)
        .opacity(animasyonTamamlandi ? 1 : 0)
    }
    
    private var limitBorcGostergesi: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("detailed_reports.credit_card_analysis.limit_debt_indicator")
                .font(.headline)
            
            let kartBilgisi: (limit: Double, borc: Double, kullanilabilir: Double)
            
            if let kart = secilenKart {
                kartBilgisi = veri.kartBilgileri[kart.id] ?? (0, 0, 0)
            } else {
                // Tüm kartların toplamı
                kartBilgisi = veri.kartBilgileri.values.reduce((0, 0, 0)) { result, bilgi in
                    (result.0 + bilgi.limit, result.1 + bilgi.borc, result.2 + bilgi.kullanilabilir)
                }
            }
            
            // Dairesel gösterge
            ZStack {
                // Arka plan çemberi
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 20)
                
                // Borç göstergesi
                Circle()
                    .trim(from: 0, to: kartBilgisi.limit > 0 ? kartBilgisi.borc / kartBilgisi.limit : 0)
                    .stroke(
                        kartBilgisi.borc > kartBilgisi.limit ? Color.purple : Color.red,
                        style: StrokeStyle(lineWidth: 20, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 1, dampingFraction: 0.8), value: kartBilgisi.borc)
                
                // Merkez bilgiler
                VStack(spacing: 8) {
                    Text("\(Int((kartBilgisi.borc / max(kartBilgisi.limit, 1)) * 100))%")
                        .font(.title.bold())
                    
                    Text("detailed_reports.credit_card_analysis.usage_rate")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 150, height: 150)
            .padding()
            
            // Detay kartları
            HStack(spacing: 12) {
                detayKarti(
                    baslik: "detailed_reports.credit_card_analysis.total_limit",
                    deger: kartBilgisi.limit,
                    renk: .blue
                )
                
                detayKarti(
                    baslik: "detailed_reports.credit_card_analysis.current_debt",
                    deger: kartBilgisi.borc,
                    renk: .red
                )
                
                detayKarti(
                    baslik: "detailed_reports.credit_card_analysis.available_limit",
                    deger: kartBilgisi.kullanilabilir,
                    renk: .green
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func detayKarti(baslik: LocalizedStringKey, deger: Double, renk: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(baslik)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(formatCurrency(
                amount: deger,
                currencyCode: appSettings.currencyCode,
                localeIdentifier: appSettings.languageCode
            ))
            .font(.callout.bold())
            .foregroundColor(renk)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(renk.opacity(0.1))
        .cornerRadius(8)
    }
    
    private var harcamaDagilimi: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("detailed_reports.credit_card_analysis.spending_distribution")
                .font(.headline)
            
            let harcamalar: [KategoriHarcama]
            
            if let kart = secilenKart {
                harcamalar = veri.kategoriHarcamalari[kart.id] ?? []
            } else {
                // Tüm kartların toplamı
                var toplamHarcamalar: [UUID: (kategori: Kategori, tutar: Double)] = [:]
                
                for (_, kategoriList) in veri.kategoriHarcamalari {
                    for harcama in kategoriList {
                        if let mevcut = toplamHarcamalar[harcama.kategori.id] {
                            toplamHarcamalar[harcama.kategori.id] = (harcama.kategori, mevcut.tutar + harcama.tutar)
                        } else {
                            toplamHarcamalar[harcama.kategori.id] = (harcama.kategori, harcama.tutar)
                        }
                    }
                }
                
                let toplamTutar = toplamHarcamalar.values.reduce(0) { $0 + $1.tutar }
                harcamalar = toplamHarcamalar.values.map { item in
                    KategoriHarcama(
                        kategori: item.kategori,
                        tutar: item.tutar,
                        yuzde: toplamTutar > 0 ? (item.tutar / toplamTutar * 100) : 0
                    )
                }.sorted { $0.tutar > $1.tutar }
            }
            
            if harcamalar.isEmpty {
                Text("detailed_reports.credit_card_analysis.no_spending")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                // En çok harcama yapılan kategoriyi bul
                let enYuksekHarcama = harcamalar.max { $0.tutar < $1.tutar }
                
                ForEach(harcamalar) { harcama in
                    harcamaSatiri(
                        harcama: harcama,
                        enYuksekMi: harcama.kategori.id == enYuksekHarcama?.kategori.id
                    )
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func harcamaSatiri(harcama: KategoriHarcama, enYuksekMi: Bool) -> some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: harcama.kategori.ikonAdi)
                    .font(.title3)
                    .foregroundColor(harcama.kategori.renk)
                
                Text(LocalizedStringKey(harcama.kategori.localizationKey ?? harcama.kategori.isim))
                    .font(.subheadline)
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(formatCurrency(
                        amount: harcama.tutar,
                        currencyCode: appSettings.currencyCode,
                        localeIdentifier: appSettings.languageCode
                    ))
                    .font(.callout.bold())
                    
                    Text("\(Int(harcama.yuzde))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)
                    
                    Rectangle()
                        .fill(harcama.kategori.renk)
                        .frame(width: geometry.size.width * (harcama.yuzde / 100), height: 8)
                        .animation(.spring(response: 0.5), value: harcama.yuzde)
                }
                .cornerRadius(4)
            }
            .frame(height: 8)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(enYuksekMi ? harcama.kategori.renk.opacity(0.1) : Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(enYuksekMi ? harcama.kategori.renk : Color.clear, lineWidth: 2)
        )
        .shadow(color: enYuksekMi ? harcama.kategori.renk.opacity(0.3) : .clear, radius: 5)
    }
}