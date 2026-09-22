import Testing
import Foundation
@testable import KartaCore

@Suite("Feed query — don't repeat")
struct FeedQueryDontRepeatTests {

    private func recipe(_ id: String, popularity: Int = 0) -> Recipe {
        Recipe(
            id: id,
            name: id,
            heroPhotoURL: "https://img.karta.app/\(id).jpg",
            totalMinutes: 30,
            difficulty: .easy,
            tags: [],
            ingredients: [Ingredient(name: "x", quantity: "1")],
            steps: ["paso"],
            popularity: popularity
        )
    }

    /// Recently-seen recipes are held back so the feed keeps feeling fresh.
    @Test("Recipes already seen are excluded from the feed")
    func excludesSeenRecipes() {
        let recipes = [recipe("a"), recipe("b"), recipe("c")]

        let feed = FeedQuery.feed(
            recipes: recipes,
            views: viewEntries(for: ["b"]),
            recentWindow: testRecentWindow,
            clock: testClock,
            filters: FeedFilters()
        )

        #expect(feed.map(\.id) == ["a", "c"])
    }

    /// Don't-repeat must not erase the catalog: once every recipe has been
    /// seen, the feed falls back to showing recipes again rather than going
    /// empty (history exhausted).
    @Test("When all recipes are seen, the feed is not empty")
    func fallsBackWhenHistoryExhausted() {
        let recipes = [recipe("a", popularity: 1), recipe("b", popularity: 2)]

        let feed = FeedQuery.feed(
            recipes: recipes,
            views: viewEntries(for: ["a", "b"]),
            recentWindow: testRecentWindow,
            clock: testClock,
            filters: FeedFilters()
        )

        #expect(feed.map(\.id) == ["b", "a"])
    }

    /// As the user consumes the feed one recipe at a time, a recipe already
    /// seen must not reappear until the whole catalog has been exhausted.
    @Test("Progressive consumption never repeats until history is exhausted")
    func neverRepeatsUntilExhausted() {
        let recipes = (1...5).map { recipe("r\($0)", popularity: $0) }
        var views: [ViewEntry] = []

        // Consume the top recipe five times; each pick must be brand new.
        for _ in 0..<recipes.count {
            let feed = FeedQuery.feed(
                recipes: recipes,
                views: views,
                recentWindow: testRecentWindow,
                clock: testClock,
                filters: FeedFilters()
            )
            let next = try! #require(feed.first)
            #expect(!views.contains { $0.recipeID == next.id }, "\(next.id) repeated before exhaustion")
            views.append(ViewEntry(recipeID: next.id, date: testClock.now))
        }

        #expect(views.count == recipes.count)
    }
}
