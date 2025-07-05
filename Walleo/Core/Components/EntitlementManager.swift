//
//  EntitlementManager.swift
//  Walleo
//
//  6 Temmuz 2025 – Delegate düzeltmesi
//

import Foundation
import RevenueCat
import SwiftUI

@MainActor
final class EntitlementManager: NSObject, ObservableObject, PurchasesDelegate {

    private let entitlementID = "Premium"

    @Published private(set) var hasPremiumAccess = false
    @Published private(set) var isLoaded = false

    override init() {
        super.init()
        Purchases.shared.delegate = self
        Task { await refresh() }
    }

    func refresh() async {
        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            hasPremiumAccess = customerInfo
                .entitlements[entitlementID]?
                .isActive == true
        } catch {
            Logger.log("Entitlement sorgusunda hata: \(error)",
                       log: Logger.service, type: .error)
        }
        isLoaded = true
    }

    // 🔁 Delegate metodu – canlı dinleme
    nonisolated func purchases(_ purchases: Purchases,
                               receivedUpdated customerInfo: CustomerInfo) {
        Task { @MainActor in
            let active = customerInfo.entitlements[entitlementID]?.isActive == true
            if self.hasPremiumAccess != active {
                self.hasPremiumAccess = active
                Logger.log("Delegate: Premium = \(active)", log: Logger.service)
            }
        }
    }
}
