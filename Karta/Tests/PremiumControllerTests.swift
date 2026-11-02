import Foundation
import Testing
import KartaCore
import KartaPresentation
@testable import Karta

/// `PremiumController`'s outcome→action mapping, driven through its
/// injected `Environment`: successful purchase, Ask to Buy pending,
/// cancellation, failure, restore-empty, restore-found and the
/// transaction-update (expiry / later approval) path — all asserting what
/// the controller reports to the store.
///
/// These run in the default `Karta` test plan (and CI): they answer the
/// StoreKit calls themselves, so no `SKTestSession` is needed. The real
/// end-to-end StoreKit suite lives in `KartaStoreKit.xctestplan`, off CI
/// until a hosted image can host a test store
/// (https://github.com/nicoamigosa/karta/issues/170).
@Suite("PremiumController maps App Store outcomes to store actions", .serialized)
struct PremiumControllerTests {

    /// The App Store answers a test controls.
    @MainActor
    private struct Double {
        var entitlement: Entitlement = .free
        var products: [Paywall.Product] = Self.plans
        var purchase: (Paywall.Plan) async -> PremiumService.PurchaseOutcome = { _ in .failed }
        var restore: () async -> Entitlement? = { nil }
        var report: (@MainActor (Entitlement) -> Void)?

        static let plans: [Paywall.Product] = [
            Paywall.Product(plan: .yearly, price: 49.99, displayPrice: "$49.99",
                            currencyCode: "USD", localeIdentifier: "en_US",
                            trial: .available(days: 7)),
            Paywall.Product(plan: .monthly, price: 6.99, displayPrice: "$6.99",
                            currencyCode: "USD", localeIdentifier: "en_US",
                            trial: .available(days: 7))
        ]
    }

    private final class DoubleBox: @unchecked Sendable {
        var double: Double

        @MainActor
        init(_ double: Double) { self.double = double }
    }

    /// A store already past onboarding, reported free so the cupo and the
    /// ways in are live.
    @MainActor
    private func freeStore() -> KartaStore {
        let store = KartaStore(state: KartaState(
            onboarding: OnboardingState(
                intoleranceAnswer: .answered([]),
                householdSize: 2
            ),
            safetyProfile: SafetyProfile(intolerances: [])
        ))
        store.send(.entitlementChanged(.free))
        return store
    }

    /// A started controller on an injected environment, with the paywall
    /// open and ready to purchase.
    @MainActor
    private func openPremium(
        store: KartaStore,
        double: DoubleBox
    ) async -> PremiumController {
        let premium = PremiumController(store: store, environment: environment(double))
        await premium.start()
        await premium.open(entry: .cupoLine)
        return premium
    }

    @MainActor
    private func environment(_ box: DoubleBox) -> PremiumController.Environment {
        PremiumController.Environment(
            currentEntitlement: { box.double.entitlement },
            loadProducts: { box.double.products },
            purchase: { plan in await box.double.purchase(plan) },
            restore: { await box.double.restore() },
            observeUpdates: { report in
                box.double.report = report
                return Task {}
            }
        )
    }

    @Test("Start reports the App Store entitlement and loads the plans")
    @MainActor
    func startReportsEntitlementAndPlans() async throws {
        let endsAt = Date(timeIntervalSinceNow: 7 * 24 * 3600)
        let store = freeStore()
        let premium = PremiumController(
            store: store,
            environment: environment(DoubleBox(Double(entitlement: .trial(endsAt: endsAt))))
        )
        await premium.start()

        #expect(store.state.entitlement == .trial(endsAt: endsAt))
        #expect(premium.products == Double.plans)
    }

    @Test("A successful purchase celebrates and lifts the cupo")
    @MainActor
    func purchaseSucceededCelebrates() async throws {
        let store = freeStore()
        let double = DoubleBox(Double(purchase: { plan in
            #expect(plan == .yearly)
            return .succeeded(.premium)
        }))
        let premium = await openPremium(store: store, double: double)
        #expect(store.state.paywall?.phase == .ready)

        await premium.purchase()

        #expect(store.state.paywall?.phase == .welcome)
        #expect(store.state.entitlement == .premium)
        #expect(store.cookbook.saveCap == nil)
        #expect(store.showsGoPremium == false)
    }

    @Test("Ask to Buy leaves the sheet pending; the approval finishes it")
    @MainActor
    func purchasePendingThenApproved() async throws {
        let store = freeStore()
        let double = DoubleBox(Double(purchase: { _ in .pending }))
        let premium = await openPremium(store: store, double: double)

        await premium.purchase()
        #expect(store.state.paywall?.phase == .pending)
        #expect(store.state.entitlement == .free)

        // Ask to Buy approval arrives on Transaction.updates: while the
        // sheet is pending the controller reports .purchaseSucceeded.
        let report = try #require(double.double.report)
        report(.premium)

        #expect(store.state.paywall?.phase == .welcome)
        #expect(store.state.entitlement == .premium)
        #expect(store.cookbook.saveCap == nil)
    }

    @Test("A cancelled purchase returns the sheet to ready")
    @MainActor
    func purchaseCancelledReturnsToReady() async throws {
        let store = freeStore()
        let double = DoubleBox(Double(purchase: { _ in .cancelled }))
        let premium = await openPremium(store: store, double: double)

        await premium.purchase()

        #expect(store.state.paywall?.phase == .ready)
        #expect(store.state.entitlement == .free)
        #expect(store.cookbook.saveCap != nil)
    }

    @Test("A failed purchase shows the note, not an alert")
    @MainActor
    func purchaseFailedShowsNote() async throws {
        let store = freeStore()
        let double = DoubleBox(Double(purchase: { _ in .failed }))
        let premium = await openPremium(store: store, double: double)

        await premium.purchase()

        #expect(store.state.paywall?.phase == .failed)
        #expect(store.state.paywall?.note != nil)
        #expect(store.state.entitlement == .free)
    }

    @Test("Restore with nothing on this Apple ID shows the toast")
    @MainActor
    func restoreNothingShowsToast() async throws {
        let store = freeStore()
        let double = DoubleBox(Double(restore: { nil }))
        let premium = await openPremium(store: store, double: double)

        await premium.restore()

        #expect(store.state.restoreToast != nil)
        #expect(store.state.paywall?.phase == .ready)
        #expect(store.state.entitlement == .free)
    }

    @Test("Restore that finds a subscription celebrates")
    @MainActor
    func restoreFoundCelebrates() async throws {
        let store = freeStore()
        let double = DoubleBox(Double(restore: { .premium }))
        let premium = await openPremium(store: store, double: double)

        await premium.restore()

        #expect(store.state.paywall?.phase == .welcome)
        #expect(store.state.entitlement == .premium)
        #expect(store.cookbook.saveCap == nil)
    }

    @Test("An expiry on Transaction.updates brings the ways in back")
    @MainActor
    func expiredSubscriptionReturnsToFree() async throws {
        let endsAt = Date(timeIntervalSinceNow: 3600)
        let store = freeStore()
        let double = DoubleBox(Double(entitlement: .trial(endsAt: endsAt)))
        let premium = PremiumController(
            store: store,
            environment: environment(double)
        )
        await premium.start()
        #expect(store.state.entitlement == .trial(endsAt: endsAt))

        // The renewal lapsing (or a revocation) arrives on updates as
        // the new entitlement; the controller reports entitlementChanged.
        let report = try #require(double.double.report)
        report(.free)

        #expect(store.state.entitlement == .free)
        #expect(store.showsGoPremium)
        #expect(store.cookbook.saveCap != nil)
    }
}
