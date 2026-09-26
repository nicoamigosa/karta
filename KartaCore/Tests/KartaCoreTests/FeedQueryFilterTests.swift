import Testing
import Foundation
@testable import KartaCore

@Suite("Feed query — hard filters")
struct FeedQueryFilterTests {

    private func recipe(
        _ id: String,
        minutes: Int = 30,
        difficulty: Difficulty = .easy,
        primaryCourse: Course = .dinner,
        additionalCourses: Set<Course> = [],
        diets: Set<Diet> = [],
        practicalTags: Set<PracticalTag> = []
    ) -> Recipe {
        Recipe(
            id: id,
            name: id,
            heroPhoto: .remote(URL(string: "https://img.karta.app/\(id).jpg")!),
            totalMinutes: minutes,
            difficulty: difficulty,
            servings: 4,
            primaryCourse: primaryCourse,
            additionalCourses: additionalCourses,
            diets: diets,
            practicalTags: practicalTags,
            ingredients: [Ingredient(name: "x", quantity: "1")],
            steps: ["paso"],
            allergenReview: .reviewed([])
        )
    }

    @Test("maxMinutes filter excludes recipes that take too long")
    func filtersByMaxMinutes() {
        let recipes = [
            recipe("quick", minutes: 15),
            recipe("slow", minutes: 60),
            recipe("borderline", minutes: 30),
        ]

        let feed = FeedQuery.feed(
            recipes: recipes,
            views: [],
            recentWindow: testRecentWindow,
            clock: testClock,
            filters: FeedFilters(maxMinutes: 30)
        )

        let ids = Set(feed.newRecipes.map(\.id))
        #expect(ids == ["quick", "borderline"])
    }

    @Test("maxDifficulty filter keeps recipes up to the chosen difficulty")
    func filtersByMaxDifficulty() {
        let recipes = [
            recipe("e", difficulty: .easy),
            recipe("m", difficulty: .medium),
            recipe("h", difficulty: .hard),
        ]

        let feed = FeedQuery.feed(
            recipes: recipes,
            views: [],
            recentWindow: testRecentWindow,
            clock: testClock,
            filters: FeedFilters(maxDifficulty: .medium)
        )

        #expect(feed.newRecipes.map(\.id) == ["e", "m"])
    }

    @Test("A practical-tag filter keeps recipes with that tag")
    func filtersByOnePan() {
        let recipes = [
            recipe("one-pan-dish", practicalTags: [.onePan]),
            recipe("many-pans", practicalTags: [.oven]),
        ]

        let feed = FeedQuery.feed(
            recipes: recipes,
            views: [],
            recentWindow: testRecentWindow,
            clock: testClock,
            filters: FeedFilters(practicalTags: [.onePan])
        )

        #expect(feed.newRecipes.map(\.id) == ["one-pan-dish"])
    }

    @Test("A Course filter matches primary and additional Courses")
    func filtersByPrimaryOrAdditionalCourse() {
        let recipes = [
            recipe("primary-lunch", primaryCourse: .lunch),
            recipe("also-lunch", additionalCourses: [.lunch]),
            recipe("dinner-only"),
        ]

        let feed = FeedQuery.feed(
            recipes: recipes,
            views: [],
            recentWindow: testRecentWindow,
            clock: testClock,
            filters: FeedFilters(course: .lunch)
        )

        #expect(feed.newRecipes.map(\.id) == ["primary-lunch", "also-lunch"])
    }

    @Test("A vegetarian filter also includes vegan recipes")
    func veganSatisfiesVegetarianFilter() {
        let recipes = [
            recipe("vegetarian", diets: [.vegetarian]),
            recipe("vegan", diets: [.vegan]),
            recipe("unlabelled"),
        ]

        let feed = FeedQuery.feed(
            recipes: recipes,
            views: [],
            recentWindow: testRecentWindow,
            clock: testClock,
            filters: FeedFilters(diet: .vegetarian)
        )

        #expect(feed.newRecipes.map(\.id) == ["vegetarian", "vegan"])
    }

    @Test("Filters compose: time, difficulty and one-pan apply together")
    func filtersCompose() {
        let recipes = [
            recipe("match", minutes: 20, difficulty: .easy, practicalTags: [.onePan]),
            recipe("too-slow", minutes: 90, difficulty: .easy, practicalTags: [.onePan]),
            recipe("too-hard", minutes: 20, difficulty: .hard, practicalTags: [.onePan]),
            recipe("many-pans", minutes: 20, difficulty: .easy),
        ]

        let feed = FeedQuery.feed(
            recipes: recipes,
            views: [],
            recentWindow: testRecentWindow,
            clock: testClock,
            filters: FeedFilters(
                maxMinutes: 30,
                maxDifficulty: .medium,
                practicalTags: [.onePan]
            )
        )

        #expect(feed.newRecipes.map(\.id) == ["match"])
    }

    @Test("The frontier is recomputed from the active filters")
    func tighteningFiltersCanSurfaceTheFrontierImmediately() {
        let notYetSeenButTooSlow = recipe("too-slow", minutes: 60)
        let alreadySeenAndCompatible = recipe("already-seen", minutes: 15)

        let feed = FeedQuery.feed(
            recipes: [notYetSeenButTooSlow, alreadySeenAndCompatible],
            views: [ViewEntry(recipeID: alreadySeenAndCompatible.id, date: testClock.now)],
            recentWindow: testRecentWindow,
            clock: testClock,
            filters: FeedFilters(maxMinutes: 30)
        )

        #expect(feed.newRecipes.isEmpty)
        #expect(feed.items == [.frontier, .alreadySeen(alreadySeenAndCompatible)])
        #expect(feed.status == .exhausted)
    }
}
