//
//  KrediRaporuView.swift
//  Walleo
//
//  Created by Mustafa Turan on 14.07.2025.
//


// Dosya: /Users/mt/Documents/GitHub/Walleo/Walleo/Features/ReportDetailed/KrediRaporuView.swift

import SwiftUI
import Charts

struct KrediRaporuView: View {
    @EnvironmentObject var appSettings: AppSettings
    let veri: KrediRaporuVerisi
    
    @State private var secilenKredi: Hesap?
    @State private var animasyonTamamlandi = false
    @State private var odemeUyarisiGoster = false
    @State private var odenecekTaksit: KrediTaksitDetayi?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Başlık
                baslikView
                
                // Kredi Seçici
                if veri.krediler.count > 1 {
                    krediSecici
                }
                
                // Kredi İlerleme Kartı
                if let kredi = secilenKredi ?? veri.krediler.first,
                   let krediDetay = veri.krediDetaylari[kredi.id] {
                    krediIlerlemeKarti(kredi: kredi, detay: krediDetay)
                }
                
                // Ödeme Takvimi
                odemeTakvimi
            }
            .padding()
        }
        .onAppear {
            secilenKredi = veri.krediler.first
            withAnimation(.easeOut(duration: 0.8)) {
                animasyonTamamlandi = true
            }
        }
        .confirmationDialog(
            "detailed_reports.loan_report.payment_confirmation_title",
            isPresented: $odemeUyarisiGoster,
            presenting: odenecekTaksit
        ) { taksit in
            Button("detailed_reports.loan_report.mark_as_paid") {
                // Ödeme işlemi
            }
            Button("common.cancel", role: .cancel) { }
        }
    }
    
    private var baslikView: some View {
        HStack {
            Image(systemName: "banknote.fill")
                .font(.title2)
                .foregroundColor(.indigo)
            
            Text("detailed_reports.loan_report.title")
                .font(.title2.bold())
            
            Spacer()
        }
        .padding(.bottom, 10)
    }
    
    private var krediSecici: some View {
        Picker("detailed_reports.loan_report.loan_picker", selection: $secilenKredi) {
            ForEach(veri.krediler, id: \.id) { kredi in
                Text(kredi.isim)
                    .tag(kredi as Hesap?)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
    }
    
    private func krediIlerlemeKarti(kredi: Hesap, detay: KrediDetayi) -> some View {
        VStack(spacing: 20) {
            // Ana ilerleme göstergesi
            VStack(spacing: 12) {
                HStack {
                    Text(kredi.isim)
                        .font(.title3.bold())
                    
                    Spacer()
                    
                    Text("\(detay.odenenTaksitSayisi)/\(detay.toplamTaksitSayisi)")
                        .font(.title3.bold())
                        .foregroundColor(.indigo)
                }
                
                // İlerleme çubuğu
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Arka plan
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 20)
                        
                        // İlerleme
                        RoundedRectangle(cornerRadius: 10)
                            .fill(
                                LinearGradient(
                                    colors: [Color.indigo, Color.blue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(
                                width: geometry.size.width * (Double(detay.odenenTaksitSayisi) / Double(detay.toplamTaksitSayisi)),
                                height: 20
                            )
                            .animation(.spring(response: 1, dampingFraction: 0.8), value: animasyonTamamlandi)
                        
                        // Yüzde metni
                        Text("\(Int((Double(detay.odenenTaksitSayisi) / Double(detay.toplamTaksitSayisi)) * 100))%")
                            .font(.caption.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                    }
                }
                .frame(height: 20)
                
                Text("detailed_reports.loan_report.installments_paid")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .scaleEffect(animasyonTamamlandi ? 1 : 0.95)
            .opacity(animasyonTamamlandi ? 1 : 0)
            
            // Detay kartları
            HStack(spacing: 12) {
                detayKarti(
                    baslik: "detailed_reports.loan_report.total_amount",
                    deger: detay.toplamKrediTutari,
                    ikon: "banknote",
                    renk: .blue
                )
                
                detayKarti(
                    baslik: "detailed_reports.loan_report.remaining_principal",
                    deger: detay.kalanAnapara,
                    ikon: "minus.circle",
                    renk: .red
                )
            }
            
            // Sonraki taksit bilgisi
            if let sonrakiTaksit = detay.donemIcindekiTaksitler.first(where: { !$0.odendiMi }) {
                sonrakiTaksitKarti(taksit: sonrakiTaksit)
            }
        }
    }
    
    private func detayKarti(baslik: LocalizedStringKey, deger: Double, ikon: String, renk: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: ikon)
                    .font(.title3)
                    .foregroundColor(renk)
                
                Text(baslik)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(formatCurrency(
                amount: deger,
                currencyCode: appSettings.currencyCode,
                localeIdentifier: appSettings.languageCode
            ))
            .font(.callout.bold())
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(renk.opacity(0.1))
        .cornerRadius(12)
    }
    
    private func sonrakiTaksitKarti(taksit: KrediTaksitDetayi) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Label("detailed_reports.loan_report.next_installment", systemImage: "calendar.badge.clock")
                    .font(.subheadline.bold())
                    .foregroundColor(.orange)
                
                Text(taksit.odemeTarihi.formatted(date: .complete, time: .omitted))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(formatCurrency(
                    amount: taksit.taksitTutari,
                    currencyCode: appSettings.currencyCode,
                    localeIdentifier: appSettings.languageCode
                ))
                .font(.title3.bold())
            }
            
            Spacer()
            
            // Kalan gün sayısı
            VStack {
                let kalanGun = Calendar.current.dateComponents([.day], from: Date(), to: taksit.odemeTarihi).day ?? 0
                
                Text("\(kalanGun)")
                    .font(.title.bold())
                    .foregroundColor(kalanGun <= 7 ? .red : .orange)
                
                Text("detailed_reports.loan_report.days_left")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color.orange.opacity(0.1), Color.red.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var odemeTakvimi: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("detailed_reports.loan_report.payment_calendar")
                .font(.headline)
            
            if let kredi = secilenKredi ?? veri.krediler.first,
               let detay = veri.krediDetaylari[kredi.id] {
                
                ForEach(detay.donemIcindekiTaksitler) { taksit in
                    taksitSatiri(taksit: taksit)
                        .opacity(animasyonTamamlandi ? 1 : 0)
                        .offset(x: animasyonTamamlandi ? 0 : -20)
                        .animation(
                            .spring(response: 0.5)
                            .delay(Double(detay.donemIcindekiTaksitler.firstIndex(where: { $0.id == taksit.id }) ?? 0) * 0.05),
                            value: animasyonTamamlandi
                        )
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func taksitSatiri(taksit: KrediTaksitDetayi) -> some View {
        Button {
            if !taksit.odendiMi {
                odenecekTaksit = taksit
                odemeUyarisiGoster = true
            }
        } label: {
            HStack(spacing: 16) {
                // Durum ikonu
                ZStack {
                    Circle()
                        .fill(taksit.odendiMi ? Color.green : Color.gray.opacity(0.3))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: taksit.odendiMi ? "checkmark" : "")
                        .font(.caption.bold())
                        .foregroundColor(.white)
                }
                
                // Taksit bilgileri
                VStack(alignment: .leading, spacing: 4) {
                    Text(taksit.odemeTarihi.formatted(date: .abbreviated, time: .omitted))
                        .font(.subheadline)
                        .foregroundColor(taksit.odendiMi ? .secondary : .primary)
                    
                    Text(formatCurrency(
                        amount: taksit.taksitTutari,
                        currencyCode: appSettings.currencyCode,
                        localeIdentifier: appSettings.languageCode
                    ))
                    .font(.callout.bold())
                    .foregroundColor(taksit.odendiMi ? .secondary : .primary)
                }
                
                Spacer()
                
                // Durum etiketi
                Text(taksit.odendiMi ? 
                     "detailed_reports.loan_report.paid" : 
                     "detailed_reports.loan_report.pending"
                )
                .font(.caption.bold())
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(taksit.odendiMi ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                .foregroundColor(taksit.odendiMi ? .green : .orange)
                .cornerRadius(6)
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(taksit.odendiMi)
    }
}