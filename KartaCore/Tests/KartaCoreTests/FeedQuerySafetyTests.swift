import Testing
import Foundation
@testable import KartaCore

@Suite("Feed query — intolerance safety")
struct FeedQuerySafetyTests {

    private func recipe(_ id: String, contains: [Allergen] = []) -> Recipe {
        Recipe(
            id: id,
            name: id,
            heroPhotoURL: "https://img.karta.app/\(id).jpg",
            totalMinutes: 30,
            difficulty: .easy,
            tags: [],
            ingredients: [Ingredient(name: "x", quantity: "1")],
            steps: ["paso"],
            contains: contains
        )
    }

    /// Exhaustive guard: derive the test matrix from the closed vocabulary,
    /// then assert the exact safe IDs for every active-intolerance subset.
    @Test("Every allergen combination returns exactly the safe recipe IDs")
    func everyIntoleranceCombinationIsSafe() {
        let allergens = Allergen.allCases

        // One recipe per allergen, plus multi-allergen and fully-safe recipes.
        var recipes = allergens.map { recipe("only-\($0.rawValue)", contains: [$0]) }
        recipes.append(recipe("dairy-and-gluten", contains: [.dairy, .gluten]))
        recipes.append(recipe("safe"))

        // Every subset of the allergen set as an active intolerance filter.
        for mask in 0..<(1 << allergens.count) {
            let active = Set(allergens.enumerated().compactMap { idx, allergen in
                (mask & (1 << idx)) != 0 ? allergen : nil
            })

            let feed = FeedQuery.feed(
                recipes: recipes,
                views: [],
                recentWindow: testRecentWindow,
                clock: testClock,
                filters: FeedFilters(intolerances: active)
            )

            let expectedIDs = allergens
                .filter { !active.contains($0) }
                .map { "only-\($0.rawValue)" }
                + ([.dairy, .gluten].allSatisfy { !active.contains($0) } ? ["dairy-and-gluten"] : [])
                + ["safe"]

            #expect(feed.map(\.id) == expectedIDs)
            #expect(!feed.isEmpty)
        }
    }

    /// Boundary: with no recipes there is simply nothing to show.
    @Test("An empty recipe set yields an empty feed")
    func emptyRecipesYieldEmptyFeed() {
        let feed = FeedQuery.feed(
            recipes: [],
            views: [],
            recentWindow: testRecentWindow,
            clock: testClock,
            filters: FeedFilters(intolerances: [.gluten])
        )
        #expect(feed.isEmpty)
    }

    /// Boundary: an empty intolerance filter excludes nothing on safety grounds.
    @Test("No active intolerances keeps every recipe")
    func noIntolerancesKeepsAll() {
        let recipes = [recipe("a", contains: [.gluten]), recipe("b", contains: [.nuts])]
        let feed = FeedQuery.feed(
            recipes: recipes,
            views: [],
            recentWindow: testRecentWindow,
            clock: testClock,
            filters: FeedFilters()
        )
        #expect(Set(feed.map(\.id)) == ["a", "b"])
    }
}
