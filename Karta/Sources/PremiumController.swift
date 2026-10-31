import Foundation
import Observation
import StoreKit
import KartaCore
import KartaPresentation

/// Owns the StoreKit↔store plumbing for the app's lifetime: reads the
/// entitlement at launch, keeps the products loaded and forwards every
/// App Store outcome as a `KartaAction`. Views call `open`, `purchase` and
/// `restore`; all rules stay in `KartaPresentation`.
@MainActor
@Observable
final class PremiumController {
    private(set) var products: [Paywall.Product] = []
    private var updatesTask: Task<Void, Never>?
    private var started = false

    let store: KartaStore

    init(store: KartaStore) {
        self.store = store
    }

    /// Launch seam: report the App Store entitlement (free / trial / premium),
    /// load the storefront products and start forwarding transaction updates.
    func start() async {
        guard !started else { return }
        started = true
        store.send(.entitlementChanged(await PremiumService.currentEntitlement()))
        products = (try? await PremiumService.loadProducts()) ?? []
        updatesTask = PremiumService.observeUpdates { [weak self] entitlement in
            guard let self else { return }
            if self.store.state.paywall?.phase == .pending {
                self.store.send(.paywall(.purchaseSucceeded(entitlement)))
            } else {
                self.store.send(.entitlementChanged(entitlement))
            }
        }
    }

    /// One of the four ways in. Products are reloaded lazily if the launch
    /// load has not landed yet; the contract decides whether the sheet opens.
    func open(entry: Paywall.Entry) async {
        if products.isEmpty {
            products = (try? await PremiumService.loadProducts()) ?? []
        }
        store.send(.paywall(.open(entry, plans: products)))
    }

    /// The paywall's primary button. The contract's `canPurchase` gates
    /// `.purchaseStarted`; every StoreKit answer maps to one action.
    func purchase() async {
        guard let paywall = store.state.paywall, paywall.canPurchase else { return }
        let plan = paywall.selectedPlan
        store.send(.paywall(.purchaseStarted))
        switch await PremiumService.purchase(plan: plan) {
        case let .succeeded(entitlement):
            store.send(.paywall(.purchaseSucceeded(entitlement)))
        case .cancelled:
            store.send(.paywall(.purchaseCancelled))
        case .pending:
            store.send(.paywall(.purchasePending))
        case .failed:
            store.send(.paywall(.purchaseFailed))
        }
    }

    /// Restore purchases: `AppStore.sync()`, then found or nothing.
    func restore() async {
        store.send(.paywall(.restoreStarted))
        if let entitlement = await PremiumService.restore() {
            store.send(.paywall(.restoreFound(entitlement)))
        } else {
            store.send(.paywall(.restoreFoundNothing))
        }
    }
}
