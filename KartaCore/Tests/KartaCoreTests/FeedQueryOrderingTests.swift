import Testing
import Foundation
@testable import KartaCore

@Suite("Feed query — ordering")
struct FeedQueryOrderingTests {

    private func recipe(
        _ id: String,
        popularity: Int,
        servings: Int = 4,
        editorialDate: Date = .distantPast
    ) -> Recipe {
        Recipe(
            id: id,
            name: id,
            heroPhoto: .remote(URL(string: "https://img.karta.app/\(id).jpg")!),
            totalMinutes: 30,
            difficulty: .easy,
            servings: servings,
            tags: [],
            ingredients: [Ingredient(name: "x", quantity: "1")],
            steps: ["paso"],
            allergenReview: .reviewed([]),
            editorialDate: editorialDate,
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

        #expect(feed.newRecipes.map(\.id) == ["top", "mid", "low"])
    }

    @Test("Taste preferences move calibrated recipes ahead within the safe feed")
    func ordersCalibratedRecipesFirst() {
        var calibration = TasteCalibration()
        calibration.tap("low")

        let feed = FeedQuery.feed(
            recipes: [
                recipe("top", popularity: 90),
                recipe("low", popularity: 10),
            ],
            views: [],
            recentWindow: testRecentWindow,
            clock: testClock,
            filters: FeedFilters(),
            tastePreferences: calibration.preferences
        )

        #expect(feed.newRecipes.map(\.id) == ["low", "top"])
    }

    @Test("Different calibrations produce different feed orders")
    func differentCalibrationsChangeOrder() {
        var firstCalibration = TasteCalibration()
        firstCalibration.tap("low")
        var secondCalibration = TasteCalibration()
        secondCalibration.tap("top")
        let recipes = [
            recipe("top", popularity: 50),
            recipe("low", popularity: 50),
        ]

        let firstFeed = FeedQuery.feed(
            recipes: recipes,
            views: [],
            recentWindow: testRecentWindow,
            clock: testClock,
            filters: FeedFilters(),
            tastePreferences: firstCalibration.preferences
        )
        let secondFeed = FeedQuery.feed(
            recipes: recipes,
            views: [],
            recentWindow: testRecentWindow,
            clock: testClock,
            filters: FeedFilters(),
            tastePreferences: secondCalibration.preferences
        )

        #expect(firstFeed.newRecipes.map(\.id) == ["low", "top"])
        #expect(secondFeed.newRecipes.map(\.id) == ["top", "low"])
    }

    @Test("Household size moves recipes with matching servings nearer the front")
    func ordersByHouseholdSizeWithoutFiltering() {
        let feed = FeedQuery.feed(
            recipes: [
                recipe("serves-four", popularity: 90, servings: 4),
                recipe("serves-two", popularity: 10, servings: 2),
            ],
            views: [],
            recentWindow: testRecentWindow,
            clock: testClock,
            filters: FeedFilters(),
            householdSize: 2
        )

        #expect(feed.newRecipes.map(\.id) == ["serves-two", "serves-four"])
        #expect(Set(feed.newRecipes.map(\.id)) == ["serves-two", "serves-four"])
    }

    @Test("Fresh recipes outrank older recipes before popularity breaks the tie")
    func freshnessContributesToRankingAtInjectedTime() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let feed = FeedQuery.feed(
            recipes: [
                recipe(
                    "popular-but-old",
                    popularity: 100,
                    editorialDate: now.addingTimeInterval(-31 * 24 * 60 * 60)
                ),
                recipe(
                    "fresh-but-less-popular",
                    popularity: 1,
                    editorialDate: now.addingTimeInterval(-24 * 60 * 60)
                ),
            ],
            views: [],
            recentWindow: testRecentWindow,
            clock: TestClock(now: now),
            filters: FeedFilters()
        )

        #expect(feed.newRecipes.map(\.id) == ["fresh-but-less-popular", "popular-but-old"])
    }

    @Test("Equal ranking signals preserve the input order deterministically")
    func equalRanksKeepStableOrder() {
        let recipes = [
            recipe("first", popularity: 50),
            recipe("second", popularity: 50),
        ]

        let firstFeed = FeedQuery.feed(
            recipes: recipes,
            views: [],
            recentWindow: testRecentWindow,
            clock: testClock,
            filters: FeedFilters()
        )
        let secondFeed = FeedQuery.feed(
            recipes: recipes,
            views: [],
            recentWindow: testRecentWindow,
            clock: testClock,
            filters: FeedFilters()
        )

        #expect(firstFeed.newRecipes.map(\.id) == ["first", "second"])
        #expect(secondFeed.newRecipes.map(\.id) == ["first", "second"])
    }
}
