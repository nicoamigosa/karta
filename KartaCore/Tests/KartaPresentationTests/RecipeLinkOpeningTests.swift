import Foundation
import Testing
import KartaCore
import KartaPresentation

@Suite("Opening a recipe link")
struct RecipeLinkOpeningTests {
    private let baseURL = URL(string: "https://karta.app/r")!
    private let date = Date(timeIntervalSince1970: 1000)

    private func recipe(id: String = "sauce", review: AllergenReview = .reviewed([])) -> Recipe {
        Recipe(
            id: id, name: "Tomato sauce", heroPhoto: .local("sauce"),
            totalMinutes: 35, difficulty: .easy, servings: 4, primaryCourse: .dinner,
            ingredients: [Ingredient(name: "Tomatoes", quantity: "2")], steps: ["Simmer"],
            allergenReview: review
        )
    }

    private func state() -> KartaState {
        KartaState(
            onboarding: OnboardingState(intoleranceAnswer: .answered([.dairy]), householdSize: 2),
            navigation: AppNavigationState(world: .leftovers),
            safetyProfile: SafetyProfile(intolerances: [.dairy]),
            filterDraft: FilterDraft(maxMinutes: 1),
            shareBaseURL: baseURL
        )
    }

    @Test("Other URLs are ignored without navigation, notices or history", arguments: [
        "https://other.example/r/sauce", "https://karta.app.evil.example/r/sauce",
        "http://karta.app/r/sauce", "https://karta.app:444/r/sauce",
        "https://karta.app/recipes/sauce", "https://karta.app/rubbish/sauce",
        "https://karta.app/r", "https://karta.app/r/", "https://karta.app/r/sauce/extra",
        "https://karta.app/r/sauce/", "https://karta.app/r/sauce?other=1",
        "https://karta.app/r/sauce#other", "https://user@karta.app/r/sauce",
        "https://karta.app/r/.", "https://karta.app/r/..", "relative/r/sauce",
    ])
    @MainActor
    func ignoresOtherURLs(raw: String) throws {
        let store = KartaStore(state: state())
        let initial = store.state
        let url = try #require(URL(string: raw))
        #expect(store.openRecipeLink(url, recipes: [recipe()], at: date) == .ignored)
        #expect(store.state == initial)
    }

    @Test("Link opening is off without a base URL")
    @MainActor
    func unavailableSharing() {
        var initial = state()
        initial.shareBaseURL = nil
        let store = KartaStore(state: initial)
        #expect(store.openRecipeLink(URL(string: "https://karta.app/r/sauce")!, recipes: [recipe()], at: date) == .ignored)
        #expect(store.state == initial)
    }

    @Test("Unreviewed recipes are not offered by a shared link")
    @MainActor
    func unreviewedRecipe() throws {
        var initial = state()
        initial.navigation.push(.recipeDetail(recipeID: "old"))
        let store = KartaStore(state: initial)
        #expect(store.openRecipeLink(URL(string: "https://karta.app/r/sauce")!, recipes: [recipe(review: .unreviewed)], at: date) == .notOffered(.allergensNotChecked))
        #expect(store.state.navigation == AppNavigationState())
        #expect(store.state.viewHistory == initial.viewHistory)
        let notice = try #require(store.state.recipeNotOfferedNotice)
        #expect(notice.reason == .allergensNotChecked)
        #expect(notice.title == "We haven't checked this recipe's allergens yet")
        #expect(notice.message == "Here's your deck instead.")
        #expect(notice.icon == .magnifier)
        #expect(notice.duration == 5)
        #expect(notice.buttonTitle == nil)
        #expect(notice.action == nil)
        store.send(.dismissRecipeNotOfferedNotice)
        #expect(store.state.recipeNotOfferedNotice == nil)
        let dismissed = store.state
        store.send(.dismissRecipeNotOfferedNotice)
        #expect(store.state == dismissed)
    }

    @Test("An unanswered receiver can open only safe-deck shared recipes")
    @MainActor
    func unfinishedOnboarding() {
        var initial = state()
        initial.onboarding = OnboardingState()
        let store = KartaStore(state: initial)
        #expect(store.openRecipeLink(URL(string: "https://karta.app/r/sauce")!,
                                    recipes: [recipe(review: .reviewed([.egg]))], at: date) == .notOffered(.intolerancesUnanswered([.egg])))
        #expect(store.state.viewHistory == initial.viewHistory)
        guard case .reverse = store.openRecipeLink(URL(string: "https://karta.app/r/sauce")!,
                                                   recipes: [recipe()], at: date) else {
            Issue.record("The safe-deck shared recipe should open")
            return
        }
        #expect(store.state.viewHistory.openings == [OpenEntry(recipeID: "sauce", date: date)])
    }


    @Test("Set mine closes the unanswered notice and answering stays on the Feed", arguments: [false, true])
    @MainActor
    func setMineDoesNotReopenLink(restored: Bool) throws {
        let initial = restored
            ? KartaState(snapshot: UserSnapshot(profile: nil), shareBaseURL: baseURL)
            : KartaState(safetyProfile: SafetyProfile(intolerances: []), shareBaseURL: baseURL)
        let store = KartaStore(state: initial)
        _ = store.openRecipeLink(URL(string: "https://karta.app/r/sauce")!,
                                 recipes: [recipe(review: .reviewed([.egg]))], at: date)
        let notice = try #require(store.state.recipeNotOfferedNotice)
        #expect(notice.title == "This recipe has egg")
        #expect(notice.message == "Tell Karta what you avoid to open it.")
        #expect(notice.icon == .shield)
        #expect(notice.duration == 8)
        #expect(notice.hasAction)
        #expect(notice.buttonTitle == "Set mine")
        let action = try #require(notice.action)
        guard case .setMine = action else {
            Issue.record("The notice should use the existing Set mine action")
            return
        }
        store.send(.onboarding(action))
        #expect(store.state.recipeNotOfferedNotice == nil)
        #expect(store.state.onboarding.panel == .firstRun)
        store.send(.onboarding(.chooseFirstRunHousehold(2)))
        store.send(.onboarding(.showMyCards))
        #expect(store.state.onboarding.intoleranceAnswer == .answered([]))
        #expect(store.state.onboarding.panel == nil)
        #expect(store.state.navigation == AppNavigationState())
        #expect(store.state.viewHistory == initial.viewHistory)
    }

    @Test("Generated links round-trip an encoded recipe id with either base path spelling", arguments: [false, true])
    @MainActor
    func encodedRecipeID(trailingSlash: Bool) throws {
        let recipe = recipe(id: "a?b#c/d café")
        var initial = state()
        initial.shareBaseURL = URL(string: trailingSlash ? "https://karta.app/r/" : "https://karta.app/r")
        let store = KartaStore(state: initial)
        let payload = try #require(RecipeShare(baseURL: initial.shareBaseURL).payload(for: recipe))
        let reverse = try #require(store.reversePresentation(for: recipe))
        #expect(store.openRecipeLink(payload.url, recipes: [recipe], at: date) == .reverse(reverse))
        #expect(store.state.viewHistory.openings == [OpenEntry(recipeID: "a?b#c/d café", date: date)])
    }

    @Test("Links never offer a recipe containing an Intolerancia, including deliberate saves", arguments: [false, true])
    @MainActor
    func unsafeRecipe(saved: Bool) throws {
        let recipe = recipe(review: .reviewed([.dairy]))
        var initial = state()
        if saved { _ = initial.cookbook.save(recipe.id) }
        let store = KartaStore(state: initial)
        #expect(store.openRecipeLink(URL(string: "https://karta.app/r/sauce")!, recipes: [recipe], at: date) == .notOffered(.intolerances([.dairy])))
        #expect(store.state.viewHistory == initial.viewHistory)
        #expect(store.state.cookbook == initial.cookbook)
        #expect(store.state.navigation == AppNavigationState())
        let notice = try #require(store.state.recipeNotOfferedNotice)
        #expect(notice.title == "This recipe has dairy, which you avoid")
        #expect(!notice.hasAction)
    }

    @Test("Allergen names use only matching Intolerancias, or every allergen while unanswered",
          arguments: [false, true], [1, 2, 3])
    @MainActor
    func allergenNames(unanswered: Bool, count: Int) throws {
        let allergens = Set([Allergen.gluten, .dairy, .nuts].prefix(count))
        let names = ["gluten", "dairy and gluten", "dairy, gluten and nuts"][count - 1]
        // Egg is in the recipe but not avoided; fish is avoided but not in the recipe.
        let recipe = recipe(review: .reviewed(unanswered ? allergens : allergens.union([.egg])))
        var initial = unanswered
            ? KartaState(snapshot: UserSnapshot(profile: nil), shareBaseURL: baseURL)
            : state()
        if !unanswered {
            KartaReducer.reduce(&initial, action: .filter(.setSafetyProfile(
                SafetyProfile(intolerances: [.dairy, .gluten, .nuts, .fish]))))
        }
        initial.navigation.push(.recipeDetail(recipeID: "old"))
        initial.viewHistory.recordView(recipeID: "old", at: date)
        initial.viewHistory.recordOpen(recipeID: "old", at: date)
        let store = KartaStore(state: initial)
        let reason: RecipeLinkNotOfferedReason = unanswered
            ? .intolerancesUnanswered(allergens) : .intolerances(allergens)
        #expect(store.openRecipeLink(URL(string: "https://karta.app/r/sauce")!,
                                    recipes: [recipe], at: date) == .notOffered(reason))
        let notice = try #require(store.state.recipeNotOfferedNotice)
        #expect(notice.reason == reason)
        #expect(notice.title == (unanswered ? "This recipe has \(names)" : "This recipe has \(names), which you avoid"))
        #expect(notice.message == (unanswered ? "Tell Karta what you avoid to open it." : "Here's your deck instead."))
        #expect(notice.icon == .shield)
        #expect(notice.duration == (unanswered ? 8 : 5))
        #expect(notice.hasAction == unanswered)
        #expect((notice.action != nil) == unanswered)
        #expect(notice.buttonTitle == (unanswered ? "Set mine" : nil))
        #expect(store.state.navigation == AppNavigationState())
        #expect(store.state.viewHistory == initial.viewHistory)
        #expect(store.state.recipeGoneNotice == nil)
        store.send(.dismissRecipeNotOfferedNotice)
        #expect(store.state.recipeNotOfferedNotice == nil)
        let dismissed = store.state
        store.send(.dismissRecipeNotOfferedNotice)
        #expect(store.state == dismissed)
    }

    @Test("Not checked wins over Intolerancias, which win over not answered")
    func reasonPrecedence() {
        #expect(RecipeLinkNotOfferedReason.reason(for: recipe(review: .unreviewed),
            intolerances: [.dairy], hasAnsweredIntolerances: false) == .allergensNotChecked)
        #expect(RecipeLinkNotOfferedReason.reason(for: recipe(review: .reviewed([.dairy, .egg])),
            intolerances: [.dairy], hasAnsweredIntolerances: false) == .intolerances([.dairy]))
        #expect(RecipeLinkNotOfferedReason.reason(for: recipe(review: .reviewed([.dairy, .egg])),
            intolerances: [], hasAnsweredIntolerances: false) == .intolerancesUnanswered([.dairy, .egg]))
        #expect(RecipeLinkNotOfferedReason.reason(for: recipe(),
            intolerances: Set(Allergen.allCases), hasAnsweredIntolerances: false) == nil)
    }

    @Test("Gone and not-offered notices replace each other, and ignored links preserve the notice")
    @MainActor
    func noticesReplaceEachOther() {
        let store = KartaStore(state: state())
        let url = URL(string: "https://karta.app/r/sauce")!
        #expect(store.openRecipeLink(url, recipes: [], at: date) == .gone)
        #expect(store.openRecipeLink(url, recipes: [recipe(review: .unreviewed)], at: date)
            == .notOffered(.allergensNotChecked))
        #expect(store.state.recipeGoneNotice == nil)
        #expect(store.state.recipeNotOfferedNotice != nil)
        store.send(.dismissRecipeGoneNotice)
        let notOffered = store.state
        #expect(store.openRecipeLink(URL(string: "https://other.example/r/sauce")!, recipes: [], at: date) == .ignored)
        #expect(store.state == notOffered)
        #expect(store.openRecipeLink(url, recipes: [], at: date) == .gone)
        #expect(store.state.recipeNotOfferedNotice == nil)
        #expect(store.state.recipeGoneNotice != nil)
        let gone = store.state
        store.send(.dismissRecipeNotOfferedNotice)
        #expect(store.state == gone)
    }

    @Test("A gone recipe opens the Feed with a notice the shell clears once")
    @MainActor
    func goneRecipe() throws {
        var initial = state()
        initial.navigation.push(.recipeDetail(recipeID: "old"))
        let store = KartaStore(state: initial)
        let result = store.openRecipeLink(URL(string: "https://karta.app/r/missing")!, recipes: [], at: date)
        #expect(result == .gone)
        #expect(store.state.navigation.world == .forYou)
        #expect(store.state.navigation.routes.isEmpty)
        #expect(store.state.viewHistory == initial.viewHistory)
        let notice = try #require(store.state.recipeGoneNotice)
        #expect(notice.title == "This recipe is no longer on Karta")
        #expect(notice.message == "Here's your deck instead.")
        store.send(.dismissRecipeGoneNotice)
        #expect(store.state.recipeGoneNotice == nil)
        let snapshot = store.state
        store.send(.dismissRecipeGoneNotice)
        #expect(store.state == snapshot)
    }

    @Test("A safe link opens the reverse over the current Mundo and records an Apertura")
    @MainActor
    func opensReverse() throws {
        let recipe = recipe()
        let store = KartaStore(state: state())
        let result = store.openRecipeLink(URL(string: "https://karta.app/r/sauce")!, recipes: [recipe], at: date)
        let reverse = try #require(store.reversePresentation(for: recipe))
        #expect(result == .reverse(reverse))
        #expect(store.state.navigation.world == .leftovers)
        #expect(store.state.navigation.routes == [.recipeDetail(recipeID: "sauce")])
        #expect(store.state.viewHistory.openings == [OpenEntry(recipeID: "sauce", date: date)])
        #expect(store.state.viewHistory.entries.isEmpty)
    }
}
