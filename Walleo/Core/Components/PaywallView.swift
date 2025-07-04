import SwiftUI
import RevenueCat
import RevenueCatUI // YENİ: UI kütüphanesini import ediyoruz

struct PaywallView: View {
    @State var offering: Offering? = nil

    var body: some View {
        Group {
            if let offering = offering {
                // --- DEĞİŞİKLİK BURADA ---
                // RevenueCat.PaywallView yerine doğrudan PaywallView'ı çağırıyoruz.
                // Çünkü artık RevenueCatUI'ı import ettik.
                RevenueCatUI.PaywallView(offering: offering)
            } else {
                ProgressView()
            }
        }
        .onAppear {
            Purchases.shared.getOfferings { (offerings, error) in
                if let offering = offerings?.current {
                    self.offering = offering
                }
            }
        }
    }
}
