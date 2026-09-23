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
            allergenReview: .reviewed([]),
            popularity: popularity
        )
    }

    /// Recently-seen recipes are held below the frontier so the feed keeps
    /// feeling fresh without hiding the compatible catalog.
    @Test("Recipes already seen are held below the frontier")
    func holdsSeenRecipesBelowFrontier() {
        let recipes = [recipe("a"), recipe("b"), recipe("c")]

        let feed = FeedQuery.feed(
            recipes: recipes,
            views: viewEntries(for: ["b"]),
            recentWindow: testRecentWindow,
            clock: testClock,
            filters: FeedFilters()
        )

        #expect(feed.newRecipes.map(\.id) == ["a", "c"])
        #expect(feed.alreadySeenRecipes.map(\.id) == ["b"])
    }

    /// Don't-repeat must not erase the catalog: once every recipe has been
    /// seen, the feed reports exhaustion while still exposing those recipes
    /// below the frontier.
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

        #expect(feed.newRecipes.isEmpty)
        #expect(feed.alreadySeenRecipes.map(\.id) == ["b", "a"])
        #expect(feed.status == .exhausted)
        #expect(!feed.isEmpty)
    }

    /// As the user consumes the new stretch one recipe at a time, a recipe
    /// already seen must not reappear there until its view expires.
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
            let next = try! #require(feed.newRecipes.first)
            #expect(!views.contains { $0.recipeID == next.id }, "\(next.id) repeated before exhaustion")
            views.append(ViewEntry(recipeID: next.id, date: testClock.now))
        }

        #expect(views.count == recipes.count)
    }

    @Test("Feed exposes new recipes, a frontier, and already-seen recipes separately")
    func exposesFrontierBetweenNewAndAlreadySeenRecipes() {
        let newRecipe = recipe("new", popularity: 2)
        let alreadySeenRecipe = recipe("already-seen", popularity: 1)
        let feed = FeedQuery.feed(
            recipes: [newRecipe, alreadySeenRecipe],
            views: [ViewEntry(recipeID: alreadySeenRecipe.id, date: testClock.now)],
            recentWindow: testRecentWindow,
            clock: testClock,
            filters: FeedFilters()
        )

        #expect(feed.newRecipes == [newRecipe])
        #expect(feed.alreadySeenRecipes == [alreadySeenRecipe])
        #expect(feed.items == [
            .new(newRecipe),
            .frontier,
            .alreadySeen(alreadySeenRecipe),
        ])
        #expect(feed.status == .ready)
    }

    @Test("Opening below the frontier records an opening without renewing the view")
    func openingBelowFrontierRegistersWithoutRenewing() throws {
        let openedRecipe = recipe("opened")
        let otherRecipe = recipe("other")
        let firstViewDate = testClock.now.addingTimeInterval(-60)
        let openingDate = testClock.now
        var history = ViewHistory(
            entries: [ViewEntry(recipeID: openedRecipe.id, date: firstViewDate)]
        )

        let beforeOpening = FeedQuery.feed(
            recipes: [openedRecipe, otherRecipe],
            views: history.entries,
            recentWindow: testRecentWindow,
            clock: testClock,
            filters: FeedFilters()
        )
        #expect(beforeOpening.alreadySeenRecipes == [openedRecipe])

        history.recordOpen(recipeID: openedRecipe.id, at: openingDate)
        #expect(history.openings == [
            OpenEntry(recipeID: openedRecipe.id, date: openingDate),
        ])

        history.recordView(
            recipeID: openedRecipe.id,
            at: openingDate.addingTimeInterval(60)
        )
        #expect(history.entries == [
            ViewEntry(recipeID: openedRecipe.id, date: firstViewDate),
        ])
    }
}
