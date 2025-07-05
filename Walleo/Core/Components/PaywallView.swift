import SwiftUI
import RevenueCat
import RevenueCatUI   // UI kitini import ettik

struct PaywallView: View {

    // Teklif (offering) ve olası hata için state değişkenleri
    @State private var offering: Offering? = nil
    @State private var loadError: Error?  = nil

    var body: some View {
        Group {
            if let offering {
                // Teklif geldiyse ödeme duvarını göster
                RevenueCatUI.PaywallView(offering: offering)
            } else if let loadError {
                // Teklif alınamadıysa kullanıcıya basit bir mesaj
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text("Abonelik bilgileri alınamadı:")
                        .bold()
                    Text(loadError.localizedDescription)
                        .multilineTextAlignment(.center)
                        .font(.footnote)
                    Button("Tekrar Dene") {
                        fetchOfferings()
                    }
                }
                .padding()
            } else {
                // Yükleniyor
                ProgressView()
            }
        }
        .onAppear { fetchOfferings() }
    }

    /// RevenueCat'ten güncel teklif paketini çeker
    private func fetchOfferings() {
        Purchases.shared.getOfferings { offerings, error in
            if let current = offerings?.current {
                self.offering = current
            } else if let error {
                self.loadError = error
            }
        }
    }
}

