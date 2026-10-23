import Foundation
import Testing
import KartaCore
import KartaPresentation

@Suite("Feed empty states")
struct FeedEmptyStateTests {
    @Test("The seed distinguishes empty filters from a matching feed")
    @MainActor
    func seedFilters() throws {
        let recipes = try SeedResourceAdapter().loadRecipes()
        let store = KartaStore(state: state(draft: FilterDraft(maxMinutes: 20, practicalTags: [.onePan])))
        #expect(store.feedEmptyState(recipes: recipes, clock: EmptyStateClock()) ==
                .noMatchForFilters(summary: "No one-pan recipe is ready in 20 min.",
                                   keptIntolerances: "dairy stays hidden"))
        store.send(.filter(.apply(FilterDraft(maxMinutes: 30, practicalTags: [.onePan]))))
        #expect(store.feedEmptyState(recipes: recipes, clock: EmptyStateClock()) == FeedEmptyState.none)
    }

    @Test("An incompatible reviewed catalog is empty for the profile regardless of filters",
          arguments: Allergen.allCases)
    func profileWins(_ allergen: Allergen) throws {
        let seed = try SeedResourceAdapter().loadRecipes()
        let recipes = seed.filter {
            if case let .reviewed(allergens) = $0.allergenReview { return allergens.contains(allergen) }
            return false
        }
        for draft in [FilterDraft(), FilterDraft(maxMinutes: 1, practicalTags: [.oven])] {
            let result = state(draft: draft, intolerances: [allergen])
                .feedEmptyState(recipes: recipes, clock: EmptyStateClock())
            #expect(result == .noMatchForProfile(allergens: allergen.rawValue))
        }
    }

    @Test("The filter summary names each applied panel choice in sentence order", arguments: [
        (FilterDraft(maxMinutes: 20, practicalTags: [.onePan]), "No one-pan recipe is ready in 20 min."),
        (FilterDraft(maxDifficulty: .easy, diet: .vegan), "No easy vegan recipe to show."),
        (FilterDraft(maxMinutes: 45, maxDifficulty: .medium), "No recipe is ready in 45 min and is medium or easier."),
        (FilterDraft(maxMinutes: 60, practicalTags: [.onePan, .oven]), "No one-pan oven recipe is ready in 1 hour."),
        (FilterDraft(maxMinutes: 30), "No recipe is ready in 30 min."),
        (FilterDraft(maxDifficulty: .easy), "No easy recipe to show."),
        (FilterDraft(maxDifficulty: .medium), "No recipe is medium or easier."),
        (FilterDraft(diet: .vegetarian), "No vegetarian recipe to show."),
        (FilterDraft(diet: .vegan), "No vegan recipe to show."),
        (FilterDraft(practicalTags: [.oven]), "No oven recipe to show."),
        (FilterDraft(practicalTags: [.makeAhead]), "No make-ahead recipe to show."),
        (FilterDraft(practicalTags: [.shareable]), "No shareable recipe to show."),
        (FilterDraft(course: .dessert), "No recipe to show."),
        (FilterDraft(maxMinutes: 60, maxDifficulty: .easy, diet: .vegetarian,
                     practicalTags: [.shareable, .makeAhead, .oven, .onePan]),
         "No easy vegetarian one-pan oven make-ahead shareable recipe is ready in 1 hour.")
    ])
    func filterSummary(draft: FilterDraft, expected: String) {
        let result = state(draft: draft).feedEmptyState(recipes: [recipe()], clock: EmptyStateClock())
        #expect(result == .noMatchForFilters(summary: expected, keptIntolerances: "dairy stays hidden"))
    }

    @Test("Both empty states name declared Intolerancias in vocabulary order", arguments: [
        (Set<Allergen>(), "", nil as String?),
        (Set<Allergen>([.dairy]), "dairy", "dairy stays hidden"),
        (Set<Allergen>([.gluten, .dairy]), "dairy and gluten", "dairy and gluten stay hidden"),
        (Set<Allergen>([.gluten, .egg, .dairy]), "dairy, egg and gluten", "dairy, egg and gluten stay hidden"),
        (Set(Allergen.allCases), "dairy, egg, fish, gluten and nuts",
         "dairy, egg, fish, gluten and nuts stay hidden")
    ])
    func intoleranceCopy(intolerances: Set<Allergen>, list: String, kept: String?) {
        let state = state(draft: FilterDraft(maxMinutes: 1), intolerances: intolerances)
        #expect(state.feedEmptyState(recipes: [recipe()], clock: EmptyStateClock()) ==
                .noMatchForFilters(summary: "No recipe is ready in 1 min.", keptIntolerances: kept))
        #expect(state.feedEmptyState(recipes: [], clock: EmptyStateClock()) == .noMatchForProfile(allergens: list))
    }

    @Test("Clear all filters restores the seed feed and keeps Intolerancias")
    @MainActor
    func clearFilters() throws {
        let recipes = try SeedResourceAdapter().loadRecipes()
        let store = KartaStore(state: state(draft: FilterDraft(maxMinutes: 20, practicalTags: [.onePan])))
        let profile = store.state.safetyProfile
        #expect(store.feedEmptyState(recipes: recipes, clock: EmptyStateClock()) ==
                .noMatchForFilters(summary: "No one-pan recipe is ready in 20 min.",
                                   keptIntolerances: "dairy stays hidden"))
        store.send(.filter(.reset))
        #expect(store.state.safetyProfile == profile)
        #expect(store.state.filterDraft == FilterDraft())
        #expect(store.feedEmptyState(recipes: recipes, clock: EmptyStateClock()) == FeedEmptyState.none)
    }

    @Test("Recipes below the Frontera keep an exhausted feed nonempty")
    func exhausted() throws {
        let recipes = try SeedResourceAdapter().loadRecipes()
        let clock = EmptyStateClock()
        var state = state()
        for recipe in recipes {
            KartaReducer.reduce(&state, action: .recordView(recipeID: recipe.id, at: clock.now))
        }
        let feed = try #require(state.feed(recipes: recipes, clock: clock))
        #expect(feed.status == .exhausted)
        #expect(!feed.alreadySeenRecipes.isEmpty)
        #expect(state.feedEmptyState(recipes: recipes, clock: clock) == FeedEmptyState.none)
    }

    @Test("An unreviewed recipe cannot turn profile emptiness into filter emptiness")
    func unreviewedCatalog() {
        let state = state(draft: FilterDraft(maxMinutes: 1))
        let recipes = [recipe(review: .unreviewed), recipe(review: .reviewed([.dairy]))]
        #expect(state.feedEmptyState(recipes: recipes, clock: EmptyStateClock()) ==
                .noMatchForProfile(allergens: "dairy"))
        #expect(state.feedEmptyState(recipes: recipes + [recipe()], clock: EmptyStateClock()) ==
                .noMatchForFilters(summary: "No recipe is ready in 1 min.", keptIntolerances: "dairy stays hidden"))
    }

    @Test("Empty-state presentation is unavailable until onboarding completes")
    func incompleteOnboarding() {
        let state = KartaState(safetyProfile: SafetyProfile(intolerances: [.dairy]))
        #expect(state.feedEmptyState(recipes: [recipe()], clock: EmptyStateClock()) == nil)
    }

    private func recipe(review: AllergenReview = .reviewed([])) -> Recipe {
        Recipe(id: "rice", name: "Rice", heroPhoto: .remote(URL(string: "https://img.karta.app/test.jpg")!),
               totalMinutes: 90, difficulty: .hard, servings: 2, primaryCourse: .dinner,
               ingredients: [Ingredient(name: "Rice", quantity: "1 cup")], steps: ["Cook rice"],
               allergenReview: review)
    }

    private func state(draft: FilterDraft = FilterDraft(), intolerances: Set<Allergen> = [.dairy]) -> KartaState {
        KartaState(onboarding: OnboardingState(intoleranceAnswer: .answered(intolerances), householdSize: 2),
                   safetyProfile: SafetyProfile(intolerances: intolerances), filterDraft: draft)
    }
}

private struct EmptyStateClock: KartaClock {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
}
