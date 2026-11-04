import Foundation
import Testing
import KartaCore
import KartaPresentation

@Suite("Leftovers presentation contract")
struct LeftoversPresentationTests {
    @Test("Leftovers keeps overlap before Gusto and household, ignores Vistas and has no Frontera")
    func orderedDeck() throws {
        let source = recipe("source", keys: ["onion", "potato"])
        let one = recipe("one", keys: ["onion"], servings: 2)
        let two = recipe("two", keys: ["onion", "potato"], servings: 6)
        var state = state(cooks: [CookEntry(recipeID: "source", date: now)])
        state.viewHistory.recordView(recipeID: "two", at: now)
        state.viewHistory.recordOpen(recipeID: "one", at: now)
        let feed = state.leftoversFeed(recipes: [source, one, two], clock: clock)
        #expect(feed.recipes.map(\.id) == ["two", "one"])
        #expect(feed.items == [.new(two), .new(one)])
        #expect(state.lastCard(recipeID: "one", world: .leftovers, recipes: [source, one, two], clock: clock)?.hint == "That's all your leftovers")
        #expect(state.lastCard(recipeID: "two", world: .leftovers, recipes: [source, one, two], clock: clock) == nil)
    }

    @Test("The pill and reverse use recipe order and distinct source recipes", arguments: [1, 2, 3])
    func explanations(count: Int) throws {
        let keys = ["potatoes", "eggs", "onion"]
        let sources = (0..<count).map { recipe("source-\($0)", keys: [keys[$0]]) }
        let target = recipe("target", keys: Array(keys.prefix(count)))
        let catalog = sources + [target]
        let state = state(cooks: sources.enumerated().map {
            CookEntry(recipeID: $0.element.id, date: now.addingTimeInterval(Double(-$0.offset)))
        })
        let card = try #require(state.cardPresentation(for: target, world: .leftovers, recipes: catalog, clock: clock))
        #expect(card.leftoversPill == (count == 1 ? "potatoes" : "potatoes + \(count - 1)"))
        #expect(state.cardPresentation(for: target)?.leftoversPill == nil)
        let expected = ["Uses the potatoes left from your source-0",
                        "Uses the potatoes and eggs left from your source-0 and source-1",
                        "Uses the potatoes, eggs and onion left from what you cooked this week"]
        #expect(state.reversePresentation(for: target, openedFrom: .leftovers, recipes: catalog, clock: clock)?.leftoversNote == expected[count - 1])
        #expect(state.reversePresentation(for: target)?.leftoversNote == nil)
    }

    @Test("The whole seed passes the pill fit check, the signed sample agrees and a wide fixture fails")
    func catalogFit() throws {
        let seed = try SeedResourceAdapter().loadRecipes()
        try LeftoversPillFit.validate(seed)
        #expect(abs(LeftoversPillFit.pillWidth("coconut cream + 2") - 161) < 2)
        let stew = try #require(seed.first { $0.id == "lentil-stew" })
        #expect(abs(LeftoversPillFit.availableWidth(for: stew) - 163) < 2)
        let wide = recipe("too-wide", keys: ["an extremely wide ingredient that cannot fit beside the chips"])
        #expect(throws: RecipeCatalogDecodingError.leftoversPillDoesNotFit(recipeID: "too-wide", ingredientID: wide.ingredients[0].id)) {
            try RecipeCatalog.decode(from: JSONEncoder().encode([wide]))
        }
    }

    @Test("Empty states follow profile, explicit cooks, reuse and filters precedence with signed copy")
    func emptyStates() throws {
        let source = recipe("Spanish Tortilla", keys: ["potatoes", "eggs", "onion"])
        let target = recipe("Lentil Stew", keys: ["potatoes", "onion"])
        var state = state()
        #expect(state.leftoversEmptyState(recipes: [], clock: clock).title == "No recipes fit your intolerances yet")
        var empty = state.leftoversEmptyState(recipes: [source, target], clock: clock)
        #expect(empty.title == "Nothing cooked yet")
        #expect(empty.line == "Cook a recipe and tell us how it turned out. Recipes that use what's left over show up here.")
        state.cookHistory = [CookEntry(recipeID: source.id, date: now, wasInferred: true)]
        #expect(state.leftoversEmptyState(recipes: [source, target], clock: clock) == empty)
        state.cookHistory = [CookEntry(recipeID: source.id, date: now.addingTimeInterval(-9 * 86400))]
        empty = state.leftoversEmptyState(recipes: [source, target], clock: clock)
        #expect(empty.title == "Nothing to reuse right now")
        #expect(empty.line == "You last cooked Spanish Tortilla 9 days ago. Leftovers looks back 7 days.")
        state.cookHistory = [CookEntry(recipeID: source.id, date: now)]
        empty = state.leftoversEmptyState(recipes: [source], clock: clock)
        #expect(empty.line == "No other recipe uses what your Spanish Tortilla left over.")
        #expect(empty.primaryButtonTitle == "Go to For You")
        KartaReducer.reduce(&state, action: .filter(.apply(FilterDraft(maxMinutes: 20))))
        empty = state.leftoversEmptyState(recipes: [source, target], clock: clock)
        #expect(empty.title == "Nothing fits these filters")
        #expect(empty.line == "No leftover recipe is ready in 20 min.")
        #expect(empty.primaryButtonTitle == "Change filters")
        #expect(empty.secondaryButtonTitle == "Clear all filters")
        KartaReducer.reduce(&state, action: .filter(.reset))
        #expect(state.leftoversEmptyState(recipes: [source, target], clock: clock) == .none)
    }

    @Test("An explicit session offers See once per recipe, for Good and Not great", arguments: [CookOutcome.thumbsUp, .thumbsDown])
    @MainActor
    func seeToast(outcome: CookOutcome) throws {
        let source = recipe("Spanish Tortilla", keys: ["potatoes", "eggs", "onion"])
        let target = recipe("Lentil Stew", keys: ["potatoes", "onion"])
        let catalog = [source, target]
        let store = KartaStore(state: state(), recipes: catalog, clock: clock)
        store.send(.setFeedAnchor(ScrollAnchor(recipeID: target.id, relativeOffset: 0), world: .leftovers))
        store.send(.startCooking(source, startedAt: now.timeIntervalSince1970 - 100))
        store.send(.nextStep(now: now.timeIntervalSince1970 - 1))
        store.send(.respond(outcome))
        #expect(store.state.leftoversToast == nil)
        store.send(.exitCooking)
        let toast = try #require(store.state.leftoversToast)
        #expect(toast.title == "1 idea for your leftovers")
        #expect(toast.line == "From the potatoes, eggs and onion of your Spanish Tortilla")
        #expect(toast.buttonTitle == "See")
        #expect(toast.duration == 5)
        store.send(.closeLeftoversToast(.see))
        #expect(store.state.navigation.world == .leftovers)
        #expect(store.state.navigation.anchor(for: .leftovers) == nil)
        #expect(store.state.session?.isExited == true)
        #expect(store.state.leftoversToast == nil)
        let snapshot = try #require(UserSnapshot.restore(from: store.state.userSnapshot.encoded()).snapshot)
        let restored = KartaStore(state: KartaState(snapshot: snapshot), recipes: catalog, clock: clock)
        #expect(restored.state.leftoversToastHistory.shownRecipeIDs == [source.id])
        restored.send(.startCooking(source, startedAt: now.timeIntervalSince1970 - 50))
        restored.send(.nextStep(now: now.timeIntervalSince1970 - 1))
        restored.send(.respond(outcome))
        restored.send(.exitCooking)
        #expect(restored.state.leftoversToast == nil)
    }

    @Test("Starting another session clears a pending toast from the previous cook")
    @MainActor
    func newSessionClearsToast() throws {
        let source = recipe("source", keys: ["onion"])
        let target = recipe("target", keys: ["onion"])
        let store = KartaStore(state: state(), recipes: [source, target], clock: clock)
        store.send(.startCooking(source, startedAt: now.timeIntervalSince1970 - 100))
        store.send(.nextStep(now: now.timeIntervalSince1970 - 1))
        store.send(.respond(.thumbsUp))
        store.send(.exitCooking)
        #expect(store.state.leftoversToast != nil)
        store.send(.startCooking(target, startedAt: now.timeIntervalSince1970))
        #expect(store.state.leftoversToast == nil)
    }

    @Test("Three dismissals retire See permanently and See resets the streak across snapshots", arguments: [false, true])
    @MainActor
    func toastRetirement(seeThird: Bool) throws {
        let sources = (0..<4).map { recipe("source-\($0)", keys: ["onion"]) }
        let catalog = sources + [recipe("idea", keys: ["onion"])]
        var store = KartaStore(state: state(), recipes: catalog, clock: clock)
        for index in 0..<4 {
            store.send(.startCooking(sources[index], startedAt: now.timeIntervalSince1970 - 100))
            store.send(.nextStep(now: now.timeIntervalSince1970 - 1))
            store.send(.respond(.thumbsDown))
            store.send(.exitCooking)
            store.send(.exitCooking)
            if index == 3 && !seeThird {
                #expect(store.state.leftoversToast == nil)
                #expect(store.state.leftoversToastHistory.consecutiveDismissals == 3)
                #expect(store.state.leftoversToastHistory.shownRecipeIDs.count == 3)
                continue
            }
            let toast = try #require(store.state.leftoversToast)
            #expect(toast.title == (index == 3 ? "1 idea for your leftovers" : "\(4 - index) ideas for your leftovers"))
            store.send(.closeLeftoversToast(index == 2 && seeThird ? .see : .dismissed))
            store.send(.closeLeftoversToast(.dismissed))
            let expectedStreak = seeThird && index >= 2 ? index - 2 : index + 1
            #expect(store.state.leftoversToastHistory.consecutiveDismissals == expectedStreak)
            let snapshot = try #require(UserSnapshot.restore(from: store.state.userSnapshot.encoded()).snapshot)
            store = KartaStore(state: KartaState(snapshot: snapshot), recipes: catalog, clock: clock)
            #expect(store.state.leftoversToast == nil)
            #expect(store.state.leftoversToastHistory.consecutiveDismissals == expectedStreak)
        }
    }

    @Test("Recipe-gone wins the toast slot and discards See before and after a cook", arguments: [false, true])
    @MainActor
    func recipeGoneWins(beforeCook: Bool) throws {
        let source = recipe("source", keys: ["onion"])
        let catalog = [source, recipe("target", keys: ["onion"])]
        var initial = state()
        initial.shareBaseURL = URL(string: "https://karta.app/r")
        let store = KartaStore(state: initial, recipes: catalog, clock: clock)
        func gone() {
            _ = store.openRecipeLink(URL(string: "https://karta.app/r/missing")!, recipes: catalog, at: now)
        }
        if beforeCook { gone() }
        store.send(.startCooking(source, startedAt: now.timeIntervalSince1970 - 100))
        store.send(.nextStep(now: now.timeIntervalSince1970 - 1))
        store.send(.respond(.thumbsUp))
        store.send(.exitCooking)
        if !beforeCook {
            #expect(store.state.leftoversToast != nil)
            gone()
        }
        #expect(store.state.recipeGoneNotice != nil)
        #expect(store.state.leftoversToast == nil)
        store.send(.dismissRecipeGoneNotice)
        #expect(store.state.leftoversToast == nil)
    }

    @Test("Not-offered wins the toast slot and discards See before and after a cook", arguments: [false, true])
    @MainActor
    func recipeNotOfferedWins(beforeCook: Bool) throws {
        let source = recipe("source", keys: ["onion"])
        let catalog = [source, recipe("target", keys: ["onion"]),
                       recipe("blocked", keys: ["onion"], allergens: [.dairy])]
        var initial = state()
        initial.shareBaseURL = URL(string: "https://karta.app/r")
        KartaReducer.reduce(&initial, action: .filter(.setSafetyProfile(SafetyProfile(intolerances: [.dairy]))))
        let store = KartaStore(state: initial, recipes: catalog, clock: clock)
        func notOffered() {
            _ = store.openRecipeLink(URL(string: "https://karta.app/r/blocked")!, recipes: catalog, at: now)
        }
        if beforeCook { notOffered() }
        store.send(.startCooking(source, startedAt: now.timeIntervalSince1970 - 100))
        store.send(.nextStep(now: now.timeIntervalSince1970 - 1))
        store.send(.respond(.thumbsUp))
        store.send(.exitCooking)
        if !beforeCook {
            #expect(store.state.leftoversToast != nil)
            notOffered()
        }
        #expect(store.state.recipeNotOfferedNotice != nil)
        #expect(store.state.recipeGoneNotice == nil)
        #expect(store.state.leftoversToast == nil)
        store.send(.closeLeftoversToast(.see))
        #expect(store.state.navigation == AppNavigationState())
        store.send(.dismissRecipeNotOfferedNotice)
        #expect(store.state.leftoversToast == nil)
    }

    @Test("See requires an explicit cook and an offered idea under the active safety and filters",
          arguments: ["inferred", "no-match", "filtered", "unanswered", "cooked"])
    @MainActor
    func noToast(reason: String) {
        let source = recipe("source", keys: ["onion"], steps: reason == "inferred" ? [
            CookingStep(detail: "Prepare the onion.", summary: "Prepare"),
            CookingStep(detail: "Cook gently until tender.", summary: "Cook")
        ] : nil)
        let target = recipe("target", keys: reason == "no-match" ? ["potato"] : ["onion"],
                            allergens: reason == "unanswered" ? [.dairy] : [])
        var initial = reason == "unanswered" ? KartaState(safetyProfile: SafetyProfile(intolerances: [])) : state()
        if reason == "filtered" { KartaReducer.reduce(&initial, action: .filter(.apply(FilterDraft(maxMinutes: 20)))) }
        if reason == "cooked" { initial.cookHistory = [CookEntry(recipeID: target.id, date: now, wasInferred: true)] }
        let store = KartaStore(state: initial, recipes: [source, target], clock: clock)
        store.send(.startCooking(source, startedAt: now.timeIntervalSince1970 - 3600))
        if reason == "inferred" { store.send(.nextStep(now: now.timeIntervalSince1970 - 2)) }
        store.send(.nextStep(now: now.timeIntervalSince1970 - 1))
        if reason == "inferred" {
            #expect(store.session?.cookedEvent?.wasInferred == true)
        } else {
            store.send(.respond(.thumbsUp))
        }
        store.send(.exitCooking)
        #expect(store.state.leftoversToast == nil)
        #expect(store.state.leftoversToastHistory.shownRecipeIDs.isEmpty)
    }

    @Test("A timeout consumes See even when an Apertura has hidden its For You slot")
    @MainActor
    func timeoutAfterOpening() throws {
        let source = recipe("source", keys: ["onion"])
        let target = recipe("target", keys: ["onion"])
        let store = KartaStore(state: state(), recipes: [source, target], clock: clock)
        store.send(.startCooking(source, startedAt: now.timeIntervalSince1970 - 100))
        store.send(.nextStep(now: now.timeIntervalSince1970 - 1))
        store.send(.respond(.thumbsUp))
        store.send(.exitCooking)
        #expect(store.state.leftoversToast != nil)
        store.send(.pushRoute(.recipeDetail(recipeID: target.id)))
        store.send(.closeLeftoversToast(.dismissed))
        store.send(.popRoute)
        #expect(store.state.leftoversToast == nil)
        #expect(store.state.leftoversToastHistory.consecutiveDismissals == 1)
    }

    @Test("For You reports its absolute last card after the seen stretch without changing the Frontera")
    func forYouEnd() throws {
        let first = recipe("first", keys: ["onion"])
        let second = recipe("second", keys: ["potato"])
        var state = state()
        state.viewHistory.recordView(recipeID: first.id, at: now)
        let feed = try #require(state.feed(recipes: [first, second], clock: clock))
        #expect(feed.items == [.new(second), .frontier, .alreadySeen(first)])
        #expect(state.lastCard(recipeID: first.id, world: .forYou, recipes: [first, second], clock: clock)?.hint == "You've seen every recipe")
        #expect(state.lastCard(recipeID: second.id, world: .forYou, recipes: [first, second], clock: clock) == nil)
    }

    @Test("Overlap ties use Gusto first and household fit next, including deliberate saves")
    func overlapTies() {
        let source = recipe("source", keys: ["onion"])
        let close = recipe("close", keys: ["onion"], servings: 2)
        let saved = recipe("saved", keys: ["onion"], servings: 6)
        let catalog = [source, saved, close]
        var state = state(cooks: [CookEntry(recipeID: source.id, date: now)])
        #expect(state.leftoversFeed(recipes: catalog, clock: clock).recipes.map(\.id) == ["close", "saved"])
        KartaReducer.reduce(&state, action: .saveRecipe(saved.id))
        #expect(state.leftoversFeed(recipes: catalog, clock: clock).recipes.map(\.id) == ["saved", "close"])
    }

    @Test("The seed supplies the signed Spanish Tortilla explanation and the latest two cooks name the no-match line")
    func seedCopyAndTwoSources() throws {
        let seed = try SeedResourceAdapter().loadRecipes()
        let stew = try #require(seed.first { $0.id == "lentil-stew" })
        let state = state(cooks: [CookEntry(recipeID: "spanish-tortilla", date: now)])
        #expect(state.cardPresentation(for: stew, world: .leftovers, recipes: seed, clock: clock)?.leftoversPill == "potatoes + 1")
        #expect(state.reversePresentation(for: stew, openedFrom: .leftovers, recipes: seed, clock: clock)?.leftoversNote == "Uses the potatoes and onion left from your Spanish Tortilla")
        let first = recipe("Spanish Tortilla", keys: ["potatoes"])
        let second = recipe("Pesto Pasta", keys: ["spaghetti"])
        var noMatch = self.state(cooks: [
            CookEntry(recipeID: second.id, date: now.addingTimeInterval(-60)),
            CookEntry(recipeID: first.id, date: now),
        ])
        KartaReducer.reduce(&noMatch, action: .filter(.apply(FilterDraft(maxMinutes: 1))))
        #expect(noMatch.leftoversEmptyState(recipes: [first, second], clock: clock).line == "No other recipe uses what your Spanish Tortilla and Pesto Pasta left over.")
    }

    @Test("Old snapshots default the See history and malformed history preserves the saved bytes")
    func snapshotCompatibility() throws {
        let snapshot = UserSnapshot(profile: OnboardingProfile(intolerances: [], householdSize: 2),
            leftoversToastHistory: LeftoversToastHistory(shownRecipeIDs: ["old"], consecutiveDismissals: 2))
        var object = try #require(JSONSerialization.jsonObject(with: snapshot.encoded()) as? [String: Any])
        object.removeValue(forKey: "leftoversToastHistory")
        let old = try JSONSerialization.data(withJSONObject: object)
        #expect(UserSnapshot.restore(from: old).snapshot?.leftoversToastHistory == LeftoversToastHistory())
        object["leftoversToastHistory"] = ["shownRecipeIDs": ["old"], "consecutiveDismissals": -1]
        let malformed = try JSONSerialization.data(withJSONObject: object)
        #expect(UserSnapshot.restore(from: malformed).snapshot == nil)
        #expect(UserSnapshot.restore(from: malformed).preservedData == malformed)
    }

    let now = Date(timeIntervalSince1970: 1_800_000_000)
    var clock: LeftoversPresentationClock { LeftoversPresentationClock(now: now) }
    func state(cooks: [CookEntry] = []) -> KartaState {
        KartaState(onboarding: OnboardingState(intoleranceAnswer: .answered([]), householdSize: 2),
                   cookHistory: cooks, safetyProfile: SafetyProfile(intolerances: []))
    }
    func recipe(_ id: String, keys: [String], servings: Int = 4, allergens: Set<Allergen> = [], steps: [CookingStep]? = nil) -> Recipe {
        Recipe(id: id, name: id, heroPhoto: .local("test"), totalMinutes: 30, difficulty: .medium,
               servings: servings, primaryCourse: .dinner,
               ingredients: keys.map { Ingredient(id: $0, name: "Named \($0)",
                   structuredQuantity: .unmeasured(.toTaste), purchaseKey: $0, aisle: .produce, shortName: $0) },
               steps: steps ?? [CookingStep(detail: "Cook gently until tender.", summary: "Cook")], allergenReview: .reviewed(allergens))
    }
}
struct LeftoversPresentationClock: KartaClock { let now: Date }
