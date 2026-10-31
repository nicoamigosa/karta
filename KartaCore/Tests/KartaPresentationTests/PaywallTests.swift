import Foundation
import Testing
import KartaCore
import KartaPresentation

@Suite("Paywall")
struct PaywallTests {
    @Test("Every way in uses the real free count and yearly selection")
    @MainActor
    func opening() throws {
        for count in [3, 7, 23] {
            for entry in [Paywall.Entry.cupoLine, .sixthSaveToast, .worldMenu] {
                let store = makeStore(count: count)
                store.send(.paywall(.open(entry, plans: [])))
                let sheet = try #require(store.state.paywall)
                #expect(sheet.entry == entry)
                #expect(sheet.countLabel == "\(count) OF \(max(7, count)) SAVED")
                #expect(sheet.selectedPlan == .yearly)
                let cookbook = store.cookbook
                store.send(.paywall(.close))
                #expect(store.state.paywall == nil)
                #expect(store.cookbook == cookbook)
            }
        }
        for entitlement in [Entitlement.premium, .trial(endsAt: Date(timeIntervalSince1970: 100))] {
            let store = makeStore(count: 3)
            store.send(.entitlementChanged(entitlement))
            store.send(.paywall(.open(.worldMenu, plans: [])))
            #expect(store.state.paywall == nil)
        }
        let unresolved = KartaStore(state: KartaState(safetyProfile: SafetyProfile(intolerances: [])))
        unresolved.send(.paywall(.open(.worldMenu, plans: [])))
        #expect(unresolved.state.paywall == nil)
    }

    @Test("Reported prices produce localized yearly equivalents and floored savings")
    @MainActor
    func prices() throws {
        let store = makeStore()
        let yearly = product(.yearly, price: "49.99", display: "$49.99")
        let monthly = product(.monthly, price: "6.99", display: "$6.99")
        store.send(.paywall(.open(.worldMenu, plans: [monthly, yearly])))
        var sheet = try #require(store.state.paywall)
        #expect(sheet.plans.map(\.plan) == [.yearly, .monthly])
        #expect(sheet.plans[0].detail == "$4.17 a month, billed yearly")
        #expect(sheet.plans[0].period == "per year")
        #expect(sheet.plans[1].detail == "Billed every month")
        #expect(sheet.plans[1].period == "per month")
        #expect(sheet.savingsBadge == "SAVE 40%")
        store.send(.paywall(.selectPlan(.monthly)))
        #expect(store.state.paywall?.selectedPlan == .monthly)
        store.send(.paywall(.close))
        let euro = product(.yearly, price: "60", display: "60,00 €", currency: "EUR", locale: "de_DE")
        store.send(.paywall(.open(.worldMenu, plans: [euro])))
        sheet = try #require(store.state.paywall)
        #expect(sheet.plans[0].detail == "5,00\u{00a0}€ a month, billed yearly")
        #expect(sheet.savingsBadge == nil)
        store.send(.paywall(.close))
        let euroMonthly = product(.monthly, price: "10", display: "10,00 €", currency: "EUR", locale: "de_DE")
        store.send(.paywall(.open(.worldMenu, plans: [euroMonthly, euro])))
        #expect(store.state.paywall?.savingsBadge == "SAVE 50%")
        #expect(store.state.paywall?.plans.map(\.period) == ["per year", "per month"])
        store.send(.paywall(.close))
        store.send(.paywall(.open(.worldMenu, plans: [product(.yearly, price: "84", display: "$84"), monthly])))
        #expect(store.state.paywall?.savingsBadge == nil)
    }

    @Test("Chosen plan drives trial, used-trial and no-trial copy", arguments: [Paywall.Plan.yearly, .monthly])
    @MainActor
    func trialCopy(plan: Paywall.Plan) throws {
        let store = makeStore()
        let period = plan == .yearly ? "year" : "month"
        let renewal = "Renews automatically until you cancel; cancel in Settings at least 24 hours before it renews."
        for trial in [Paywall.Trial.available(days: 7), .used, .none] {
            let products = [product(.yearly, price: "49.99", display: "$49.99", trial: trial),
                            product(.monthly, price: "6.99", display: "$6.99", trial: trial)]
            store.send(.paywall(.open(.worldMenu, plans: products)))
            store.send(.paywall(.selectPlan(plan)))
            let sheet = try #require(store.state.paywall)
            let price = plan == .yearly ? "$49.99" : "$6.99"
            if trial == .available(days: 7) {
                #expect(sheet.buttonTitle == "Start 7-day free trial")
                #expect(sheet.renewalLine == "7 days free, then \(price) a \(period). \(renewal)")
            } else {
                #expect(sheet.buttonTitle == "Subscribe for \(price) a \(period)")
                #expect(sheet.renewalLine == (trial == .used
                    ? "Your free trial was already used on this Apple ID. \(renewal)" : renewal))
            }
            store.send(.paywall(.close))
        }
    }

    @Test("Purchase progress locks the sheet, cancellation preserves it, and outcomes show signed copy")
    @MainActor
    func purchaseStates() throws {
        let store = makeStore()
        store.send(.paywall(.open(.worldMenu, plans: [product(.monthly, price: "6.99", display: "$6.99")])))
        store.send(.paywall(.selectPlan(.monthly)))
        let original = try #require(store.state.paywall)
        let cookbook = store.cookbook
        store.send(.paywall(.purchaseStarted))
        #expect(store.state.paywall?.phase == .buying)
        #expect(store.state.paywall?.buttonTitle == "Waiting for the App Store…")
        #expect(store.state.paywall?.isDisabled == true)
        #expect(store.state.paywall?.canClose == false)
        let waiting = store.state.paywall
        store.send(.paywall(.close))
        store.send(.paywall(.selectPlan(.yearly)))
        store.send(.paywall(.restoreStarted))
        store.send(.paywall(.open(.cupoLine, plans: [])))
        #expect(store.state.paywall == waiting)
        store.send(.paywall(.purchaseCancelled))
        #expect(store.state.paywall == original)
        store.send(.paywall(.purchaseStarted))
        store.send(.paywall(.purchaseFailed))
        #expect(store.state.paywall?.phase == .failed)
        #expect(store.state.paywall?.note == "The App Store didn't answer. Check your connection and try again. You haven't been charged.")
        #expect(store.state.paywall?.buttonTitle == "Try again")
        #expect(store.state.paywall?.canClose == true)
        let failed = store.state.paywall
        store.send(.paywall(.purchaseStarted))
        store.send(.paywall(.purchaseCancelled))
        #expect(store.state.paywall == failed)
        store.send(.paywall(.purchaseStarted))
        store.send(.paywall(.purchasePending))
        #expect(store.state.paywall?.phase == .pending)
        #expect(store.state.paywall?.note == "Waiting for approval. Premium turns on by itself as soon as it's approved.")
        #expect(store.state.paywall?.buttonTitle == "Close")
        #expect(store.state.paywall?.canClose == true)
        store.send(.paywall(.close))
        #expect(store.state.paywall == nil)
        #expect(store.cookbook == cookbook)
    }

    @Test("Purchase and restore success lift the cupo and save only the K3 recipe", arguments: [false, true])
    @MainActor
    func success(restoring: Bool) throws {
        let recipe = Recipe(id: "tortilla", name: "Spanish Tortilla", heroPhoto: .local("tortilla"),
                            totalMinutes: 30, difficulty: .easy, servings: 2, primaryCourse: .dinner,
                            ingredients: [], steps: ["Cook"], allergenReview: .reviewed([]))
        for entry in [Paywall.Entry.cap(recipe), .worldMenu] {
            let store = makeStore()
            store.send(.paywall(.open(entry, plans: [product(.yearly, price: "49.99", display: "$49.99")])))
            #expect(store.state.paywall?.countLabel == "7 OF 7 SAVED")
            store.send(.paywall(restoring ? .restoreStarted : .purchaseStarted))
            if restoring {
                #expect(store.state.paywall?.phase == .restoring)
                #expect(store.state.paywall?.buttonTitle == "Waiting for the App Store…")
                #expect(store.state.paywall?.isDisabled == true)
                store.send(.paywall(.close))
                #expect(store.state.paywall != nil)
            }
            let entitlement = Entitlement.trial(endsAt: Date(timeIntervalSince1970: 500))
            store.send(.paywall(restoring ? .restoreFound(entitlement) : .purchaseSucceeded(entitlement)))
            #expect(store.state.entitlement == entitlement)
            #expect(store.cookbook.saveCap == nil)
            #expect(store.state.paywall?.phase == .welcome)
            #expect(store.state.paywall?.title == "Welcome to Premium")
            #expect(store.state.paywall?.buttonTitle == "Done")
            if case .cap = entry {
                #expect(store.cookbook.savedIDs == (0..<7).map { "r\($0)" } + ["tortilla"])
                #expect(store.state.lastSaveResult == .saved)
                #expect(store.state.paywall?.message == "Spanish Tortilla is saved. Keep every recipe you like from now on.")
            } else {
                #expect(store.cookbook.savedIDs.count == 7)
                #expect(store.state.paywall?.message == "Keep every recipe you like from now on.")
            }
            let done = store.state
            store.send(.paywall(.purchaseSucceeded(.premium)))
            #expect(store.state == done)
            store.send(.paywall(.close))
            #expect(store.state.paywall == nil)
        }
    }

    @Test("An empty restore returns unchanged and raises a dismissible one-shot toast")
    @MainActor
    func restoreEmpty() throws {
        let store = makeStore()
        store.send(.paywall(.open(.worldMenu, plans: [])))
        let original = store.state.paywall
        let cookbook = store.cookbook
        store.send(.paywall(.restoreStarted))
        store.send(.paywall(.restoreFoundNothing))
        #expect(store.state.paywall == original)
        #expect(store.cookbook == cookbook)
        #expect(store.state.restoreToast?.title == "Nothing to restore")
        #expect(store.state.restoreToast?.secondLine == "No Karta subscription on this Apple ID")
        store.send(.paywall(.dismissRestoreToast))
        #expect(store.state.restoreToast == nil)
        store.send(.paywall(.restoreFoundNothing))
        #expect(store.state.restoreToast == nil)
    }

    @Test("Paywall feature and footer copy is centralized")
    func labels() {
        #expect(Paywall.features.map(\.title) == ["Unlimited cookbook", "Shopping list", "Free for good"])
        #expect(Paywall.features.map(\.detail) == [
            "No cap. Keep every recipe worth making again.",
            "Any recipe becomes a list you tick off at the store.",
            "The feed, cooking and your intolerance filters.",
        ])
        #expect(Paywall.footer.map(\.title) == ["Restore purchases", "Terms of Use", "Privacy Policy"])
        #expect(Paywall.dismissTitle == "Not now")
    }

    @Test("K3 retains its recipe and downgrade count without saving on close")
    @MainActor
    func capClose() throws {
        let recipe = try #require(SeedResourceAdapter().loadRecipes().first { $0.id == "spanish-tortilla" })
        for count in [7, 23] {
            let store = makeStore(count: count)
            store.send(.paywall(.open(.cap(recipe), plans: [])))
            #expect(store.state.paywall?.entry == .cap(recipe))
            #expect(store.state.paywall?.countLabel == "\(count) OF \(count) SAVED")
            let cookbook = store.cookbook
            store.send(.paywall(.close))
            #expect(store.cookbook == cookbook)
            #expect(!store.cookbook.isSaved(recipe.id))
        }
    }

    @Test("A K3 recipe must be offered safely and actually hit the cupo")
    @MainActor
    func capEligibility() throws {
        let recipe = try #require(SeedResourceAdapter().loadRecipes().first { $0.id == "spanish-tortilla" })
        let belowCap = makeStore(count: 3)
        belowCap.send(.paywall(.open(.cap(recipe), plans: [])))
        #expect(belowCap.state.paywall == nil)
        let store = makeStore()
        store.send(.filter(.setSafetyProfile(SafetyProfile(intolerances: [.egg]))))
        store.send(.paywall(.open(.cap(recipe), plans: [])))
        #expect(store.state.paywall == nil)
    }

    @Test("Pending approval can finish later, while unrelated outcomes are ignored")
    @MainActor
    func approval() throws {
        let store = makeStore()
        let unopened = store.state
        store.send(.paywall(.purchaseSucceeded(.premium)))
        store.send(.paywall(.restoreFound(.premium)))
        store.send(.paywall(.purchaseFailed))
        #expect(store.state == unopened)
        store.send(.paywall(.open(.worldMenu, plans: [])))
        let noProduct = store.state
        store.send(.paywall(.purchaseStarted))
        #expect(store.state == noProduct)
        store.send(.paywall(.close))
        store.send(.paywall(.open(.worldMenu, plans: [product(.yearly, price: "49.99", display: "$49.99")])))
        let ready = store.state
        store.send(.paywall(.purchaseCancelled))
        store.send(.paywall(.purchasePending))
        store.send(.paywall(.restoreFoundNothing))
        #expect(store.state == ready)
        store.send(.paywall(.purchaseStarted))
        let buying = store.state
        store.send(.paywall(.purchaseSucceeded(.free)))
        store.send(.paywall(.restoreFound(.premium)))
        #expect(store.state == buying)
        store.send(.paywall(.purchasePending))
        #expect(store.state.paywall?.canPurchase == false)
        store.send(.paywall(.purchaseSucceeded(.premium)))
        #expect(store.state.entitlement == .premium)
        #expect(store.cookbook.saveCap == nil)
        #expect(store.cookbook.savedIDs.count == 7)
        #expect(store.state.paywall?.phase == .welcome)
    }

    private func product(
        _ plan: Paywall.Plan, price: String, display: String,
        currency: String = "USD", locale: String = "en_US",
        trial: Paywall.Trial = .available(days: 7)
    ) -> Paywall.Product {
        Paywall.Product(plan: plan, price: Decimal(string: price)!, displayPrice: display,
                        currencyCode: currency, localeIdentifier: locale, trial: trial)
    }

    @MainActor
    private func makeStore(count: Int = 7) -> KartaStore {
        let store = KartaStore(state: KartaState(
            cookbook: Cookbook(savedIDs: (0..<count).map { "r\($0)" }, saveCap: nil),
            safetyProfile: SafetyProfile(intolerances: [])
        ))
        store.send(.entitlementChanged(.free))
        return store
    }
}
