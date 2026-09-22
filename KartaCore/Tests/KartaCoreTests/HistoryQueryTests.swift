import Foundation
import Testing
@testable import KartaCore

@Suite("History-aware queries")
struct HistoryQueryTests {

    private func recipe(_ id: String) -> Recipe {
        recipe(id, ingredients: ["x"])
    }

    private func recipe(_ id: String, ingredients: [String]) -> Recipe {
        Recipe(
            id: id,
            name: id,
            heroPhotoURL: "https://img.karta.app/\(id).jpg",
            totalMinutes: 30,
            difficulty: .easy,
            tags: [],
            ingredients: ingredients.map { Ingredient(name: $0, quantity: "1") },
            steps: ["step"],
            allergenReview: .reviewed([])
        )
    }

    @Test("Feed excludes only recipes viewed inside the explicit recency window")
    func feedUsesDatedViewEntries() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let window: TimeInterval = 7 * 24 * 60 * 60
        let recipes = [recipe("recent"), recipe("expired")]
        let views = [
            ViewEntry(recipeID: "recent", date: now.addingTimeInterval(-60)),
            ViewEntry(recipeID: "expired", date: now.addingTimeInterval(-window - 1)),
        ]

        let feed = FeedQuery.feed(
            recipes: recipes,
            views: views,
            recentWindow: window,
            clock: TestClock(now: now),
            filters: FeedFilters()
        )

        #expect(feed.map(\.id) == ["expired"])
    }

    @Test("The recency window includes its edge but not future-dated history")
    func feedUsesExactWindowBoundaries() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let window: TimeInterval = 7 * 24 * 60 * 60
        let recipes = [recipe("edge"), recipe("expired"), recipe("future")]
        let views = [
            ViewEntry(recipeID: "edge", date: now.addingTimeInterval(-window)),
            ViewEntry(recipeID: "expired", date: now.addingTimeInterval(-window - 1)),
            ViewEntry(recipeID: "future", date: now.addingTimeInterval(1)),
        ]

        let feed = FeedQuery.feed(
            recipes: recipes,
            views: views,
            recentWindow: window,
            clock: TestClock(now: now),
            filters: FeedFilters()
        )

        #expect(feed.map(\.id) == ["expired", "future"])
    }

    @Test("Leftovers use only cooks inside the explicit recency window")
    func leftoversUseDatedCookEntries() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let window: TimeInterval = 7 * 24 * 60 * 60
        let recipes = [
            recipe("recent-cook", ingredients: ["onion"]),
            recipe("expired-cook", ingredients: ["rice"]),
            recipe("recent-match", ingredients: ["onion"]),
            recipe("expired-match", ingredients: ["rice"]),
        ]
        let cooks = [
            CookEntry(recipeID: "recent-cook", date: now.addingTimeInterval(-60)),
            CookEntry(recipeID: "expired-cook", date: now.addingTimeInterval(-window - 1)),
        ]

        let suggestions = LeftoversQuery.suggestions(
            recipes: recipes,
            cooks: cooks,
            recentWindow: window,
            clock: TestClock(now: now),
            filters: FeedFilters()
        )

        #expect(suggestions.map(\.id) == ["recent-match"])
    }

    @Test("Leftovers include cooks on the edge but ignore future-dated cooks")
    func leftoversUseExactWindowBoundaries() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let window: TimeInterval = 7 * 24 * 60 * 60
        let recipes = [
            recipe("edge-cook", ingredients: ["onion"]),
            recipe("future-cook", ingredients: ["garlic"]),
            recipe("edge-match", ingredients: ["onion"]),
            recipe("future-match", ingredients: ["garlic"]),
        ]
        let cooks = [
            CookEntry(recipeID: "edge-cook", date: now.addingTimeInterval(-window)),
            CookEntry(recipeID: "future-cook", date: now.addingTimeInterval(1)),
        ]

        let suggestions = LeftoversQuery.suggestions(
            recipes: recipes,
            cooks: cooks,
            recentWindow: window,
            clock: TestClock(now: now),
            filters: FeedFilters()
        )

        #expect(suggestions.map(\.id) == ["edge-match"])
    }
}
