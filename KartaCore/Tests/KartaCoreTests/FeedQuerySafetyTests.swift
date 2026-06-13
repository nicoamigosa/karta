import Testing
import Foundation
@testable import KartaCore

@Suite("Feed query — intolerance safety")
struct FeedQuerySafetyTests {

    private func recipe(_ id: String, contains: [String] = []) -> Recipe {
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

    /// Critical-severity guarantee: when an intolerance filter is active, the
    /// returned feed must NEVER include a recipe that contains that allergen.
    @Test("An active intolerance filter excludes every violating recipe")
    func excludesViolatingRecipes() {
        let recipes = [
            recipe("safe-1"),
            recipe("has-gluten", contains: ["gluten"]),
            recipe("safe-2"),
            recipe("has-gluten-and-lactose", contains: ["gluten", "lactose"]),
        ]

        let feed = FeedQuery.feed(
            recipes: recipes,
            seen: [],
            filters: FeedFilters(intolerances: ["gluten"])
        )

        let ids = feed.map(\.id)
        #expect(!ids.contains("has-gluten"))
        #expect(!ids.contains("has-gluten-and-lactose"))
        #expect(ids.contains("safe-1"))
        #expect(ids.contains("safe-2"))
    }

    /// Exhaustive guard: across the whole allergen vocabulary, and every
    /// combination of active intolerances, the feed must contain zero recipes
    /// that violate an active filter. A single violation is a critical bug.
    @Test("No combination of intolerances ever lets a violating recipe through")
    func everyIntoleranceCombinationIsSafe() {
        let allergens = ["gluten", "lactose", "nuts", "egg", "soy"]

        // One recipe per allergen, plus multi-allergen and fully-safe recipes.
        var recipes = allergens.map { recipe("only-\($0)", contains: [$0]) }
        recipes.append(recipe("gluten-and-nuts", contains: ["gluten", "nuts"]))
        recipes.append(recipe("safe"))

        // Every subset of the allergen set as an active intolerance filter.
        for mask in 0..<(1 << allergens.count) {
            let active = Set(allergens.enumerated().compactMap { idx, a in
                (mask & (1 << idx)) != 0 ? a : nil
            })

            let feed = FeedQuery.feed(
                recipes: recipes,
                seen: [],
                filters: FeedFilters(intolerances: active)
            )

            for r in feed {
                #expect(
                    r.contains.allSatisfy { !active.contains($0) },
                    "\(r.id) leaked with active intolerances \(active)"
                )
            }
        }
    }

    /// Boundary: with no recipes there is simply nothing to show.
    @Test("An empty recipe set yields an empty feed")
    func emptyRecipesYieldEmptyFeed() {
        let feed = FeedQuery.feed(
            recipes: [],
            seen: [],
            filters: FeedFilters(intolerances: ["gluten"])
        )
        #expect(feed.isEmpty)
    }

    /// Boundary: an empty intolerance filter excludes nothing on safety grounds.
    @Test("No active intolerances keeps every recipe")
    func noIntolerancesKeepsAll() {
        let recipes = [recipe("a", contains: ["gluten"]), recipe("b", contains: ["nuts"])]
        let feed = FeedQuery.feed(recipes: recipes, seen: [], filters: FeedFilters())
        #expect(Set(feed.map(\.id)) == ["a", "b"])
    }
}
