import Testing
@testable import KartaCore

/// The Leftovers loop: suggestions derived purely from cooked history overlapped
/// with recipe ingredient sets. No pantry/inventory tracking.
@Suite("Leftovers query")
struct LeftoversQueryTests {

    private func recipe(
        _ id: String,
        ingredients: [String],
        contains: [Allergen] = []
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
            cooks: cookEntries(for: ["cooked"]),
            recentWindow: testRecentWindow,
            clock: testClock,
            filters: FeedFilters()
        )

        #expect(result.map(\.id) == ["two", "one"]) // overlap 2 then 1; no-match excluded
    }

    @Test("Every vocabulary allergen is excluded from leftovers", arguments: Allergen.allCases)
    func safetyAlwaysApplies(for active: Allergen) {
        let cooked = recipe("cooked", ingredients: ["flour", "milk", "egg"])
        let unsafe = recipe(
            "unsafe-\(active.rawValue)",
            ingredients: ["flour", "milk", "egg"],
            contains: [active]
        )
        let safe = recipe("safe-\(active.rawValue)", ingredients: ["egg"])
        let all = [cooked, unsafe, safe]

        let result = LeftoversQuery.suggestions(
            recipes: all,
            cooks: cookEntries(for: ["cooked"]),
            recentWindow: testRecentWindow,
            clock: testClock,
            filters: FeedFilters(intolerances: [active])
        )

        #expect(result.map(\.id) == ["safe-\(active.rawValue)"])
        #expect(!result.isEmpty)
    }

    @Test("No cooked history yields no leftover suggestions")
    func emptyHistoryNoSuggestions() {
        let all = [recipe("a", ingredients: ["onion"]), recipe("b", ingredients: ["rice"])]

        let result = LeftoversQuery.suggestions(
            recipes: all,
            cooks: [],
            recentWindow: testRecentWindow,
            clock: testClock,
            filters: FeedFilters()
        )

        #expect(result.isEmpty)
    }

    @Test("Inferred cooks do not feed Leftovers")
    func inferredCooksAreIgnored() {
        let cooked = recipe("cooked", ingredients: ["onion"])
        let match = recipe("match", ingredients: ["onion"])

        let result = LeftoversQuery.suggestions(
            recipes: [cooked, match],
            cooks: [CookEntry(recipeID: "cooked", date: testClock.now, wasInferred: true)],
            recentWindow: testRecentWindow,
            clock: testClock,
            filters: FeedFilters()
        )

        #expect(result.isEmpty)
    }
}
