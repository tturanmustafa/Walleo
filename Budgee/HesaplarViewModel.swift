//
//  HesaplarViewModel.swift
//  Budgee
//
//  Created by Mustafa Turan on 19.06.2025.
//


// MARK: - DOSYA: HesaplarViewModel.swift
import SwiftUI
import SwiftData

@MainActor
@Observable
class HesaplarViewModel {
    var modelContext: ModelContext
    var gosterilecekHesaplar: [GosterilecekHesap] = []

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        NotificationCenter.default.addObserver(self, selector: #selector(hesaplamalariTetikle), name: .transactionsDidChange, object: nil)
    }

    @objc func hesaplamalariTetikle() {
        Task { await hesaplamalariYap() }
    }

    func hesaplamalariYap() async {
        do {
            let hesaplar = try modelContext.fetch(FetchDescriptor<Hesap>(sortBy: [SortDescriptor(\.olusturmaTarihi)]))
            let islemler = try modelContext.fetch(FetchDescriptor<Islem>())
            
            var netDegisimler: [UUID: Double] = [:]
            for islem in islemler {
                guard let hesapID = islem.hesap?.id else { continue }
                let tutarDegisimi = islem.tur == .gelir ? islem.tutar : -islem.tutar
                netDegisimler[hesapID, default: 0] += tutarDegisimi
            }
            
            var yeniListe: [GosterilecekHesap] = []
            for hesap in hesaplar {
                let netDegisim = netDegisimler[hesap.id] ?? 0
                let guncelBakiye = hesap.baslangicBakiyesi + netDegisim
                var gosterilecekHesap = GosterilecekHesap(hesap: hesap, guncelBakiye: guncelBakiye)
                
                switch hesap.detay {
                case .krediKarti(let limit, _):
                    let harcamalarToplami = netDegisim < 0 ? abs(netDegisim) : 0
                    let guncelBorc = abs(hesap.baslangicBakiyesi) + harcamalarToplami
                    let kullanilabilirLimit = max(0, limit - guncelBorc)
                    gosterilecekHesap.krediKartiDetay = .init(guncelBorc: guncelBorc, kullanilabilirLimit: kullanilabilirLimit)
                    gosterilecekHesap.guncelBakiye = -guncelBorc
                case .kredi(_, _, _, _, _, let taksitler):
                    let odenenTaksitSayisi = taksitler.filter { $0.odendiMi }.count
                    gosterilecekHesap.krediDetay = .init(kalanTaksitSayisi: taksitler.count - odenenTaksitSayisi, odenenTaksitSayisi: odenenTaksitSayisi)
                case .cuzdan:
                    break
                }
                yeniListe.append(gosterilecekHesap)
            }
            self.gosterilecekHesaplar = yeniListe
        } catch {
            print("Hesap ViewModel hesaplama hatası: \(error)")
        }
    }

    func hesabiSil(hesap: Hesap) {
        // HATA DÜZELTMESİ: Predicate yerine doğrudan ilişkiyi kullanarak
        // hem daha performanslı hem de hatasız bir yapı kuruyoruz.
        if let iliskiliIslemler = hesap.islemler {
            for islem in iliskiliIslemler {
                islem.hesap = nil
            }
        }
        modelContext.delete(hesap)
        Task { await hesaplamalariYap() }
    }
}
