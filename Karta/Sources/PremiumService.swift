import Foundation
import StoreKit
import KartaCore
import KartaPresentation

/// The provisional product identifiers from #153, kept in one place until
/// App Store Connect lands in #163. The `.storekit` file carries the same
/// strings and the test session reads them back from here.
enum PremiumProductIDs {
    static let yearly = "app.karta.premium.yearly"
    static let monthly = "app.karta.premium.monthly"
    /// The `id` of the "Karta Premium" group in `Karta.storekit`.
    static let subscriptionGroupID = "8E9D1A2B"
    static let all = [yearly, monthly]
}

/// Footer link targets — placeholders until #153 question 7.
enum PremiumLinks {
    static let termsOfUse = URL(string: "https://example.com/karta/terms")!
    static let privacyPolicy = URL(string: "https://example.com/karta/privacy")!
}

/// The shell's StoreKit 2 adapter: loads products, reads the App Store
/// entitlement, purchases, restores and forwards transaction updates. Every
/// outcome is reported to `KartaStore` as a presentation action — no rule
/// lives here beyond translating StoreKit's answers.
@MainActor
final class PremiumService {
    /// What StoreKit answered for one `.purchaseStarted`.
    enum PurchaseOutcome {
        case succeeded(Entitlement)
        case cancelled
        case pending
        case failed
    }

    /// Read the App Store entitlement for the current user: trial (with its
    /// end date), premium or free. `revoked` and expired transactions are
    /// excluded by `currentEntitlements` itself.
    static func currentEntitlement() async -> Entitlement {
        for await verification in Transaction.currentEntitlements {
            guard case let .verified(transaction) = verification,
                  PremiumProductIDs.all.contains(transaction.productID),
                  transaction.revocationDate == nil else { continue }
            if transaction.offerType == .introductory,
               let endsAt = transaction.expirationDate {
                return .trial(endsAt: endsAt)
            }
            return .premium
        }
        return .free
    }

    /// Load the two products as `Paywall.Product` — storefront prices,
    /// currency and trial status from the App Store, never hardcoded.
    static func loadProducts() async throws -> [Paywall.Product] {
        let products = try await Product.products(for: PremiumProductIDs.all)
        var result: [Paywall.Product] = []
        for product in products {
            guard let plan = plan(for: product.id) else { continue }
            result.append(await Paywall.Product(
                plan: plan,
                price: product.price,
                displayPrice: product.displayPrice,
                currencyCode: product.priceFormatStyle.currencyCode,
                localeIdentifier: product.priceFormatStyle.locale.identifier,
                trial: trialStatus(of: product)
            ))
        }
        return result
    }

    /// Purchase the product the paywall has selected, reporting every outcome.
    static func purchase(plan: Paywall.Plan) async -> PurchaseOutcome {
        let productID = self.productID(for: plan)
        do {
            let result = try await Product.products(for: [productID]).first?.purchase()
            switch result {
            case let .success(verification):
                guard case let .verified(transaction) = verification else {
                    return .failed
                }
                let entitlement = entitlement(for: transaction)
                await transaction.finish()
                return .succeeded(entitlement)
            case .userCancelled:
                return .cancelled
            case .pending:
                return .pending
            case nil, .none:
                return .failed
            @unknown default:
                return .failed
            }
        } catch {
            return .failed
        }
    }

    /// Restore purchases (`AppStore.sync()`) and read what the sync found.
    /// Returns the new entitlement, or nil when nothing was restored.
    static func restore() async -> Entitlement? {
        do {
            try await AppStore.sync()
        } catch {
            return nil
        }
        let entitlement = await currentEntitlement()
        return entitlement == .free ? nil : entitlement
    }

    /// Map one verified transaction to the contract's entitlement.
    static func entitlement(for transaction: Transaction) -> Entitlement {
        if transaction.offerType == .introductory,
           let endsAt = transaction.expirationDate {
            return .trial(endsAt: endsAt)
        }
        return .premium
    }

    /// Every transaction update — approvals finishing Ask to Buy, renewals,
    /// expirations, revocations — is one verified transaction to report.
    /// Call once at launch; the loop lives for the app's lifetime.
    static func observeUpdates(report: @MainActor @escaping (Entitlement) -> Void) -> Task<Void, Never> {
        Task { @MainActor in
            for await verification in Transaction.updates {
                guard case let .verified(transaction) = verification,
                      PremiumProductIDs.all.contains(transaction.productID) else { continue }
                let entitlement = await currentEntitlement()
                await transaction.finish()
                report(entitlement)
            }
        }
    }

    /// Days covered by an introductory offer's subscription period
    /// (P1W → 7). Only day/week/month/year units exist in StoreKit.
    private static func days(in period: Product.SubscriptionPeriod) -> Int {
        switch period.unit {
        case .day: period.value
        case .week: period.value * 7
        case .month: period.value * 30
        case .year: period.value * 365
        @unknown default: period.value
        }
    }

    /// The contract's `Paywall.Trial`: the offer exists; whether this Apple
    /// ID may still use it comes from `isEligibleForIntroOffer`.
    private static func trialStatus(of product: Product) async -> Paywall.Trial {
        guard let offer = product.subscription?.introductoryOffer else { return .none }
        let eligible = await product.subscription?.isEligibleForIntroOffer ?? false
        return eligible ? .available(days: days(in: offer.period)) : .used
    }

    private static func plan(for productID: String) -> Paywall.Plan? {
        switch productID {
        case PremiumProductIDs.yearly: .yearly
        case PremiumProductIDs.monthly: .monthly
        default: nil
        }
    }

    private static func productID(for plan: Paywall.Plan) -> String {
        switch plan {
        case .yearly: PremiumProductIDs.yearly
        case .monthly: PremiumProductIDs.monthly
        }
    }
}
