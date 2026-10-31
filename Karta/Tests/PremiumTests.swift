import Foundation
import StoreKit
import StoreKitTest
import Testing
import KartaCore
import KartaPresentation
@testable import Karta

/// The Premium flow against the bundled `Karta.storekit` configuration,
/// driven end to end through `PremiumController` and `PremiumService`:
/// products, purchase, Ask to Buy, a forced failure, restore-empty, and
/// the subscription expiring back to free (#162).
///
/// Serialized: one SKTestSession is live per process, so these must not
/// race. A live session makes `Product.purchase()` run against the Octane
/// test store — headless, no sign-in sheet. On a runtime where storekitd
/// never attaches it (SKInternalErrorDomain Code=3 — seen on the iOS 26.5
/// simulator; the iOS 27.0 sim works) products come back empty and every
/// test fails on the `products` requirement instead of hanging: the gate
/// reports the runtime honestly.
@Suite("Premium on the local StoreKit configuration", .serialized)
struct PremiumTests {

    /// The bundled configuration, copied into the test target by the
    /// project (the scheme selects it for Debug runs).
    @MainActor
    private func session() throws -> SKTestSession {
        let session = try SKTestSession(configurationFileNamed: "Karta.storekit")
        // resetToDefaultState() clears every override: it runs first.
        session.resetToDefaultState()
        session.clearTransactions()
        session.disableDialogs = true
        session.locale = Locale(identifier: "en_US")
        session.storefront = "USA"
        return session
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

    /// A controller started like launch: entitlement reported, products
    /// loaded, `Transaction.updates` forwarding. Requires the storefront
    /// to answer with both plans — a dead test store fails here.
    @MainActor
    private func startedPremium(
        store: KartaStore
    ) async throws -> PremiumController {
        let premium = PremiumController(store: store)
        let started = await withTimeout(30) {
            await premium.start()
            return true
        }
        try #require(started, "premium.start() did not finish in 30 s")
        try #require(
            premium.products.count == 2,
            "StoreKit returned no products — the test store is not attached"
        )
        return premium
    }

    /// Race an async operation against a deadline; nil on timeout.
    /// TaskGroup results must be Sendable, which is not guaranteed for
    /// every payload, so the result travels through a box and the group
    /// only decides which branch finished first.
    private func withTimeout<T>(
        _ seconds: Double,
        _ op: @escaping @Sendable () async throws -> T
    ) async -> T? {
        let box = ResultBox<T>()
        await withTaskGroup(of: Void.self) { group in
            group.addTask { box.value = try? await op() }
            group.addTask { try? await Task.sleep(for: .seconds(seconds)) }
            await group.next()
            group.cancelAll()
        }
        return box.value
    }

    /// Poll the App Store entitlement until it satisfies `predicate` or
    /// ~10 s pass; bounded so a dead test store cannot stall the suite.
    @MainActor
    private func entitlementEventually(
        _ predicate: (Entitlement) -> Bool
    ) async -> Entitlement {
        var entitlement = await PremiumService.currentEntitlement()
        for _ in 0..<40 where !predicate(entitlement) {
            try? await Task.sleep(for: .milliseconds(250))
            entitlement = await PremiumService.currentEntitlement()
        }
        return entitlement
    }

    @Test("The configuration publishes both plans with a 7-day trial")
    @MainActor
    func productsLoadWithTrial() async throws {
        let session = try session()
        let premium = try await startedPremium(store: freeStore())

        #expect(premium.products.count == 2)
        let yearly = try #require(premium.products.first { $0.plan == .yearly })
        let monthly = try #require(premium.products.first { $0.plan == .monthly })
        #expect(yearly.displayPrice == "$49.99")
        #expect(monthly.displayPrice == "$6.99")
        #expect(yearly.trial == .available(days: 7))
        #expect(monthly.trial == .available(days: 7))
        #expect(PremiumProductIDs.all.count == 2)
        session.clearTransactions()
    }

    @Test("Buying the yearly plan reports a trial entitlement and celebrates")
    @MainActor
    func purchaseCelebratesAndLiftsCupo() async throws {
        let session = try session()
        let store = freeStore()
        let premium = try await startedPremium(store: store)

        await premium.open(entry: .cupoLine)
        #expect(store.state.paywall?.entry == .cupoLine)

        // The real purchase path: `.purchaseStarted` → product.purchase()
        // on the test store → `.purchaseSucceeded(.trial)` → celebration
        // up, cupo lifted.
        let bought = await withTimeout(30) {
            await premium.purchase()
            return true
        }
        try #require(bought, "premium.purchase() did not finish in 30 s")

        #expect(store.state.paywall?.phase == .welcome)
        #expect(store.cookbook.saveCap == nil)
        #expect(store.showsGoPremium == false)
        guard case .trial = store.state.entitlement else {
            Issue.record("expected a trial entitlement, got \(store.state.entitlement)")
            return
        }
        session.clearTransactions()
    }

    @Test("Purchasing from K3 saves the recipe that hit the cap")
    @MainActor
    func purchaseFromCapSavesRecipe() async throws {
        let session = try session()
        let store = freeStore()
        let premium = try await startedPremium(store: store)
        let recipes = try SeedResourceAdapter().loadRecipes()

        // Fill the free cookbook (7 spots) so the cap is reached.
        for recipe in recipes.prefix(7) {
            store.send(.saveRecipe(recipe.id))
        }
        #expect(store.cookbook.isAtCap)

        let blocked = try #require(recipes.first { !store.cookbook.isSaved($0.id) })
        await premium.open(entry: .cap(blocked))
        #expect(store.state.paywall?.entry == .cap(blocked))

        let bought = await withTimeout(30) {
            await premium.purchase()
            return true
        }
        try #require(bought, "premium.purchase() did not finish in 30 s")

        #expect(store.state.paywall?.phase == .welcome)
        #expect(store.state.paywall?.savedRecipeName == blocked.name)
        #expect(store.cookbook.isSaved(blocked.id))
        #expect(store.cookbook.saveCap == nil)
        session.clearTransactions()
    }

    @Test("Ask to Buy leaves the paywall pending")
    @MainActor
    func askToBuyIsPending() async throws {
        let session = try session()
        session.askToBuyEnabled = true
        let store = freeStore()
        let premium = try await startedPremium(store: store)

        await premium.open(entry: .cupoLine)
        let bought = await withTimeout(30) {
            await premium.purchase()
            return true
        }
        try #require(bought, "premium.purchase() did not finish in 30 s")

        // Ask to Buy leaves the sheet on the pending note, entitlement free.
        #expect(store.state.paywall?.phase == .pending)
        #expect(store.state.entitlement == .free)
        session.clearTransactions()
    }

    @Test("A StoreKit failure shows the note, not an alert")
    @MainActor
    func failedPurchaseShowsNote() async throws {
        let session = try session()
        let store = freeStore()
        let premium = try await startedPremium(store: store)

        await premium.open(entry: .cupoLine)
        try await session.setSimulatedError(.generic(.unknown), forAPI: .purchase)
        let bought = await withTimeout(30) {
            await premium.purchase()
            return true
        }
        try #require(bought, "premium.purchase() did not finish in 30 s")

        #expect(store.state.paywall?.phase == .failed)
        #expect(store.state.entitlement == .free)
        session.clearTransactions()
    }

    @Test("Restore with nothing on this Apple ID shows the toast")
    @MainActor
    func restoreEmptyShowsToast() async throws {
        let session = try session()
        let store = freeStore()
        let premium = try await startedPremium(store: store)

        await premium.open(entry: .cupoLine)
        // `premium.restore()` runs `AppStore.sync()`; on a runtime where
        // the sync never answers, the bound fails the test instead of
        // hanging the job (the CI 25-minute timeout).
        let restored = await withTimeout(30) {
            await premium.restore()
            return true
        }
        try #require(restored, "AppStore.sync() did not answer in 30 s")

        #expect(store.state.restoreToast != nil)
        #expect(store.state.paywall?.phase == .ready)
        session.clearTransactions()
    }

    @Test("After the trial lapses the ways in come back")
    @MainActor
    func expiredTrialReturnsToFree() async throws {
        // Compress every renewal into two seconds so the expiry path is
        // exercised at speed rather than deleted with clearTransactions().
        let session = try session()
        session.timeRate = .oneRenewalEveryTwoSeconds
        let store = freeStore()
        let premium = try await startedPremium(store: store)

        await premium.open(entry: .cupoLine)
        let bought = await withTimeout(30) {
            await premium.purchase()
            return true
        }
        try #require(bought, "premium.purchase() did not finish in 30 s")
        guard case .trial = store.state.entitlement else {
            Issue.record("expected a trial before expiry, got \(store.state.entitlement)")
            return
        }

        // Expire the subscription; at the accelerated rate the current
        // period lapses within a few seconds and the entitlement drops.
        try await session.expireSubscription(
            productIdentifier: PremiumProductIDs.yearly
        )
        let entitlement = await entitlementEventually { $0 == .free }
        #expect(entitlement == .free)

        store.send(.entitlementChanged(entitlement))
        #expect(store.showsGoPremium)
        #expect(store.cookbook.saveCap != nil)
        session.clearTransactions()
    }
}

/// Carry a non-Sendable result out of a `withTaskGroup` race.
private final class ResultBox<T>: @unchecked Sendable {
    var value: T?
}

/// Anchor for `Bundle(for:)` lookups inside the test target.
private final class BundleToken {}
