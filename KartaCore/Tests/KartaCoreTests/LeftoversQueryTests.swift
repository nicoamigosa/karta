import Testing
@testable import KartaCore

/// The Leftovers loop: suggestions derived purely from cooked history overlapped
/// with recipe ingredient sets. No pantry/inventory tracking.
@Suite("Leftovers query")
struct LeftoversQueryTests {

    private func recipe(
        _ id: String,
        ingredients: [String],
        reviewedAllergens: [Allergen] = [],
        review: AllergenReview = .reviewed([]),
        totalMinutes: Int = 10,
        difficulty: Difficulty = .easy,
        tags: [RecipeTag] = []
    ) -> Recipe {
        Recipe(
            id: id, name: id, heroPhoto: .local("test"), totalMinutes: totalMinutes, difficulty: difficulty, servings: 4,
            tags: tags, ingredients: ingredients.map { Ingredient(name: $0, quantity: "1") },
            steps: ["s"],
            allergenReview: reviewedAllergens.isEmpty ? review : .reviewed(Set(reviewedAllergens))
        )
    }

    @Test("Unreviewed recipes never enter Leftovers")
    func excludesUnreviewedRecipes() {
        let cooked = recipe("cooked", ingredients: ["onion"])
        let unreviewed = recipe("unreviewed", ingredients: ["onion"], review: .unreviewed)
        let reviewed = recipe("reviewed", ingredients: ["onion"])

        let result = LeftoversQuery.suggestions(
            recipes: [cooked, unreviewed, reviewed],
            cooks: cookEntries(for: ["cooked"]),
            recentWindow: testRecentWindow,
            clock: testClock,
            filters: FeedFilters()
        )

        #expect(result.map(\.id) == ["reviewed"])
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

    @Test("Duplicate ingredient rows count once in Leftovers overlap")
    func duplicateIngredientDoesNotInflateOverlap() {
        let cooked = recipe("cooked", ingredients: ["onion", "rice"])
        let duplicate = recipe("duplicate", ingredients: ["onion", "onion", "onion"])
        let genuine = recipe("genuine", ingredients: ["onion", "rice"])

        let result = LeftoversQuery.suggestions(
            recipes: [cooked, duplicate, genuine],
            cooks: cookEntries(for: ["cooked"]),
            recentWindow: testRecentWindow,
            clock: testClock,
            filters: FeedFilters()
        )

        #expect(result.map(\.id) == ["genuine", "duplicate"])
    }

    @Test("Every vocabulary allergen is excluded from leftovers", arguments: Allergen.allCases)
    func safetyAlwaysApplies(for active: Allergen) {
        let cooked = recipe("cooked", ingredients: ["flour", "milk", "egg"])
        let unsafe = recipe(
            "unsafe-\(active.rawValue)",
            ingredients: ["flour", "milk", "egg"],
            reviewedAllergens: [active]
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

    @Test("An inferred cook never supplies ingredients to Leftovers")
    func inferredCookNoSuggestions() {
        let cooked = recipe("cooked", ingredients: ["onion"])
        let reuse = recipe("reuse", ingredients: ["onion"])
        let inferred = CookEntry(
            event: CookedEvent(recipeID: "cooked", outcome: nil, wasInferred: true),
            date: testClock.now
        )

        let result = LeftoversQuery.suggestions(
            recipes: [cooked, reuse],
            cooks: [inferred],
            recentWindow: testRecentWindow,
            clock: testClock,
            filters: FeedFilters()
        )

        #expect(result.isEmpty)
    }

    @Test("Leftovers applies every active safety and hard filter")
    func appliesFullSafetyProfile() {
        let cooked = recipe("cooked", ingredients: ["onion"])
        let safe = recipe("safe", ingredients: ["onion"], tags: [.onePan])
        let tooLong = recipe("too-long", ingredients: ["onion"], totalMinutes: 30, tags: [.onePan])
        let tooDifficult = recipe("too-difficult", ingredients: ["onion"], difficulty: .medium, tags: [.onePan])
        let notOnePan = recipe("not-one-pan", ingredients: ["onion"])
        let unsafe = recipe(
            "unsafe",
            ingredients: ["onion"],
            reviewedAllergens: [.dairy],
            tags: [.onePan]
        )

        let result = LeftoversQuery.suggestions(
            recipes: [cooked, safe, tooLong, tooDifficult, notOnePan, unsafe],
            cooks: cookEntries(for: ["cooked"]),
            recentWindow: testRecentWindow,
            clock: testClock,
            filters: FeedFilters(
                intolerances: [.dairy],
                maxMinutes: 10,
                maxDifficulty: .easy,
                requireOnePan: true
            )
        )

        #expect(result.map(\.id) == ["safe"])
    }

}
