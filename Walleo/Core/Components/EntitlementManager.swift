//
//  EntitlementManager.swift
//  Walleo
//
//  Created by Mustafa Turan on 4.07.2025.
//


import Foundation
import RevenueCat
import SwiftUI

@MainActor
class EntitlementManager: ObservableObject {
    // Uygulama genelinde kullanıcının premium erişimi olup olmadığını bu değişken tutacak.
    @Published var hasPremiumAccess: Bool = false

    init() {
        // Manager oluşturulduğunda kullanıcının mevcut durumunu kontrol et.
        updateSubscriptionStatus()
    }
    
    func updateSubscriptionStatus() {
        Purchases.shared.getCustomerInfo { (customerInfo, error) in
            // customerInfo'dan "Walleo Premium" entitlement'ının aktif olup olmadığını kontrol et.
            // "Walleo Premium" adı, App Store Connect'te oluşturduğunuz Grubun adıyla aynı olmalı.
            self.hasPremiumAccess = customerInfo?.entitlements["Walleo Premium"]?.isActive == true
            
            Logger.log("Abonelik durumu güncellendi. Premium Erişim: \(self.hasPremiumAccess)", log: Logger.service)
        }
    }
}
