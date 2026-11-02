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
    /// The StoreKit calls the controller makes, as closures so tests can
    /// answer them without an App Store backend. `.live` is the real
    /// `PremiumService` wiring; anything else is a test double.
    struct Environment {
        var currentEntitlement: () async -> Entitlement
        var loadProducts: () async throws -> [Paywall.Product]
        var purchase: (Paywall.Plan) async -> PremiumService.PurchaseOutcome
        var restore: () async -> Entitlement?
        var observeUpdates: @MainActor (@MainActor @escaping (Entitlement) -> Void) -> Task<Void, Never>

        static var live: Environment {
            Environment(
                currentEntitlement: { await PremiumService.currentEntitlement() },
                loadProducts: { try await PremiumService.loadProducts() },
                purchase: { plan in await PremiumService.purchase(plan: plan) },
                restore: { await PremiumService.restore() },
                observeUpdates: { report in PremiumService.observeUpdates(report: report) }
            )
        }
    }

    private(set) var products: [Paywall.Product] = []
    private var updatesTask: Task<Void, Never>?
    private var started = false

    let store: KartaStore
    private let environment: Environment

    init(store: KartaStore, environment: Environment = .live) {
        self.store = store
        self.environment = environment
    }

    /// Launch seam: report the App Store entitlement (free / trial / premium),
    /// load the storefront products and start forwarding transaction updates.
    func start() async {
        guard !started else { return }
        started = true
        store.send(.entitlementChanged(await environment.currentEntitlement()))
        products = (try? await environment.loadProducts()) ?? []
        updatesTask = environment.observeUpdates { [weak self] entitlement in
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
            products = (try? await environment.loadProducts()) ?? []
        }
        store.send(.paywall(.open(entry, plans: products)))
    }

    /// The paywall's primary button. The contract's `canPurchase` gates
    /// `.purchaseStarted`; every StoreKit answer maps to one action.
    func purchase() async {
        guard let paywall = store.state.paywall, paywall.canPurchase else { return }
        let plan = paywall.selectedPlan
        store.send(.paywall(.purchaseStarted))
        switch await environment.purchase(plan) {
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
        if let entitlement = await environment.restore() {
            store.send(.paywall(.restoreFound(entitlement)))
        } else {
            store.send(.paywall(.restoreFoundNothing))
        }
    }
}
