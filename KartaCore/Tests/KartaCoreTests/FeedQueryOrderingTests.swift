import Testing
import Foundation
@testable import KartaCore

@Suite("Feed query — ordering")
struct FeedQueryOrderingTests {

    private func recipe(_ id: String, popularity: Int) -> Recipe {
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

    /// Within the filtered set, more popular recipes surface first.
    @Test("Feed is ordered by popularity, most popular first")
    func ordersByPopularityDescending() {
        let recipes = [
            recipe("mid", popularity: 50),
            recipe("top", popularity: 90),
            recipe("low", popularity: 10),
        ]

        let feed = FeedQuery.feed(
            recipes: recipes,
            views: [],
            recentWindow: testRecentWindow,
            clock: testClock,
            filters: FeedFilters()
        )

        #expect(feed.map(\.id) == ["top", "mid", "low"])
    }
}
