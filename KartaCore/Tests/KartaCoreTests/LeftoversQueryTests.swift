import Testing
@testable import KartaCore

/// The Leftovers loop: suggestions derived purely from cooked history overlapped
/// with recipe ingredient sets. No pantry/inventory tracking.
@Suite("Leftovers query")
struct LeftoversQueryTests {

    private func recipe(
        _ id: String,
        ingredients: [String],
        contains: [String] = []
    ) -> Recipe {
        Recipe(
            id: id, name: id, heroPhotoURL: "", totalMinutes: 10, difficulty: .easy,
            tags: [], ingredients: ingredients.map { Ingredient(name: $0, quantity: "1") },
            steps: ["s"], contains: contains
        )
    }

    @Test("Suggestions reuse ingredients from recently-cooked recipes, most overlap first")
    func suggestsByIngredientOverlap() {
        let cooked = recipe("cooked", ingredients: ["onion", "rice", "egg"])
        let twoMatch = recipe("two", ingredients: ["onion", "rice", "beef"])
        let oneMatch = recipe("one", ingredients: ["egg", "flour"])
        let noMatch = recipe("none", ingredients: ["chocolate", "cream"])
        let all = [cooked, noMatch, oneMatch, twoMatch]

        let result = LeftoversQuery.suggestions(
            recipes: all,
            cookedRecipeIDs: ["cooked"],
            filters: FeedFilters()
        )

        #expect(result.map(\.id) == ["two", "one"]) // overlap 2 then 1; no-match excluded
    }

    @Test("Intolerance-violating recipes are never suggested, even with high overlap")
    func safetyAlwaysApplies() {
        let cooked = recipe("cooked", ingredients: ["flour", "milk", "egg"])
        let unsafe = recipe("unsafe", ingredients: ["flour", "milk", "egg"], contains: ["gluten"])
        let safe = recipe("safe", ingredients: ["egg"])
        let all = [cooked, unsafe, safe]

        let result = LeftoversQuery.suggestions(
            recipes: all,
            cookedRecipeIDs: ["cooked"],
            filters: FeedFilters(intolerances: ["gluten"])
        )

        #expect(result.map(\.id) == ["safe"]) // unsafe excluded despite full overlap
    }

    @Test("No cooked history yields no leftover suggestions")
    func emptyHistoryNoSuggestions() {
        let all = [recipe("a", ingredients: ["onion"]), recipe("b", ingredients: ["rice"])]

        let result = LeftoversQuery.suggestions(
            recipes: all, cookedRecipeIDs: [], filters: FeedFilters()
        )

        #expect(result.isEmpty)
    }
}
