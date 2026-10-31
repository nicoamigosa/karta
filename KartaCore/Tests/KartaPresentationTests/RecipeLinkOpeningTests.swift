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
    func unreviewedRecipe() {
        let initial = state()
        let store = KartaStore(state: initial)
        #expect(store.openRecipeLink(URL(string: "https://karta.app/r/sauce")!, recipes: [recipe(review: .unreviewed)], at: date) == .notOffered)
        #expect(store.state == initial)
    }

    @Test("A shared link cannot bypass unfinished onboarding")
    @MainActor
    func unfinishedOnboarding() {
        var initial = state()
        initial.onboarding = OnboardingState()
        let store = KartaStore(state: initial)
        #expect(store.openRecipeLink(URL(string: "https://karta.app/r/sauce")!, recipes: [recipe()], at: date) == .notOffered)
        #expect(store.state == initial)
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
    func unsafeRecipe(saved: Bool) {
        let recipe = recipe(review: .reviewed([.dairy]))
        var initial = state()
        if saved { _ = initial.cookbook.save(recipe.id) }
        let store = KartaStore(state: initial)
        #expect(store.openRecipeLink(URL(string: "https://karta.app/r/sauce")!, recipes: [recipe], at: date) == .notOffered)
        #expect(store.state == initial)
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
