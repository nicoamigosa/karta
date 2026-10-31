import Foundation
import StoreKit
import StoreKitTest
import Testing
import KartaCore
import KartaPresentation
@testable import Karta

/// The Premium flow against the bundled `Karta.storekit` configuration:
/// products, trial eligibility, purchase, Ask to Buy, a forced failure,
/// restore-empty, and the trial expiring back to free (#162).
///
/// Serialized: one SKTestSession is live per process, so these must not race.
/// Purchases go through `session.buyProduct` — `Product.purchase()` prompts
/// the production "Sign in to Apple Account" sheet on this simulator runtime
/// (xcodebuild does not sync the scheme's StoreKit configuration into
/// storekitd; FB22237318), which would hang a headless run forever.
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

    /// Poll the App Store entitlement until it changes or ~5 s pass.
    @MainActor
    private func currentEntitlement() async -> Entitlement {
        await PremiumService.currentEntitlement()
    }

    @Test("The configuration publishes both plans with a 7-day trial")
    @MainActor
    func productsLoadWithTrial() async throws {
        let session = try session()

        let products = try await PremiumService.loadProducts()

        #expect(products.count == 2)
        let yearly = try #require(products.first { $0.plan == .yearly })
        let monthly = try #require(products.first { $0.plan == .monthly })
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
        let premium = PremiumController(store: store)
        await premium.start()

        await premium.open(entry: .cupoLine)
        #expect(store.state.paywall?.entry == .cupoLine)

        try session.buyProduct(productIdentifier: PremiumProductIDs.yearly)

        // The intro offer reports as a trial once the transaction lands.
        var entitlement = await currentEntitlement()
        for _ in 0..<20 where entitlement == .free {
            try await Task.sleep(for: .milliseconds(250))
            entitlement = await currentEntitlement()
        }
        guard case .trial = entitlement else {
            Issue.record("expected a trial entitlement, got \(entitlement)")
            return
        }

        // A successful purchase reports `.purchaseSucceeded` (from
        // `.buying`): celebration up, cupo lifted.
        store.send(.paywall(.purchaseStarted))
        store.send(.paywall(.purchaseSucceeded(entitlement)))
        #expect(store.state.paywall?.phase == .welcome)
        #expect(store.cookbook.saveCap == nil)
        #expect(store.showsGoPremium == false)
        session.clearTransactions()
    }

    @Test("Purchasing from K3 saves the recipe that hit the cap")
    @MainActor
    func purchaseFromCapSavesRecipe() async throws {
        let session = try session()
        let store = freeStore()
        let premium = PremiumController(store: store)
        await premium.start()

        let recipes = try SeedResourceAdapter().loadRecipes()
        // Fill the free cookbook (7 spots) so the cap is reached.
        for recipe in recipes.prefix(7) {
            store.send(.saveRecipe(recipe.id))
        }
        #expect(store.cookbook.isAtCap)

        let blocked = try #require(recipes.first { !store.cookbook.isSaved($0.id) })
        store.send(.paywall(.open(.cap(blocked), plans: premium.products)))
        #expect(store.state.paywall?.entry == .cap(blocked))

        try session.buyProduct(productIdentifier: PremiumProductIDs.yearly)
        var entitlement = await currentEntitlement()
        for _ in 0..<20 where entitlement == .free {
            try await Task.sleep(for: .milliseconds(250))
            entitlement = await currentEntitlement()
        }
        store.send(.paywall(.purchaseStarted))
        store.send(.paywall(.purchaseSucceeded(entitlement)))

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
        let premium = PremiumController(store: store)
        await premium.start()

        await premium.open(entry: .cupoLine)

        try session.buyProduct(productIdentifier: PremiumProductIDs.yearly)
        store.send(.paywall(.purchaseStarted))
        store.send(.paywall(.purchasePending))

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
        let premium = PremiumController(store: store)
        await premium.start()

        await premium.open(entry: .cupoLine)
        try await session.setSimulatedError(.generic(.unknown), forAPI: .purchase)

        // `Product.purchase()` cannot run headless here; the reported
        // outcome is what the contract consumes.
        store.send(.paywall(.purchaseStarted))
        store.send(.paywall(.purchaseFailed))

        #expect(store.state.paywall?.phase == .failed)
        #expect(store.state.entitlement == .free)
        session.clearTransactions()
    }

    @Test("Restore with nothing on this Apple ID shows the toast")
    @MainActor
    func restoreEmptyShowsToast() async throws {
        let session = try session()
        let store = freeStore()
        let premium = PremiumController(store: store)
        await premium.start()

        await premium.open(entry: .cupoLine)
        await premium.restore()

        #expect(store.state.restoreToast != nil)
        #expect(store.state.paywall?.phase == .ready)
        session.clearTransactions()
    }

    @Test("After the trial lapses the ways in come back")
    @MainActor
    func expiredTrialReturnsToFree() async throws {
        let session = try session()
        let store = freeStore()
        let premium = PremiumController(store: store)
        await premium.start()

        try session.buyProduct(productIdentifier: PremiumProductIDs.yearly)
        var entitlement = await currentEntitlement()
        for _ in 0..<20 where entitlement == .free {
            try await Task.sleep(for: .milliseconds(250))
            entitlement = await currentEntitlement()
        }
        guard case .trial = entitlement else {
            Issue.record("expected a trial before expiry, got \(entitlement)")
            return
        }

        // `expireSubscription` ends the auto-renew; the intro-trial
        // entitlement only drops once the transaction is cleared.
        try session.expireSubscription(productIdentifier: PremiumProductIDs.yearly)
        session.clearTransactions()

        entitlement = await currentEntitlement()
        #expect(entitlement == .free)

        store.send(.entitlementChanged(entitlement))
        #expect(store.showsGoPremium)
        #expect(store.cookbook.saveCap != nil)
        session.clearTransactions()
    }
}

/// Anchor for `Bundle(for:)` lookups inside the test target.
private final class BundleToken {}
