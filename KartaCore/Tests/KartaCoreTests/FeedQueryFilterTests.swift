import Testing
import Foundation
@testable import KartaCore

@Suite("Feed query — hard filters")
struct FeedQueryFilterTests {

    private func recipe(
        _ id: String,
        minutes: Int = 30,
        difficulty: Difficulty = .easy,
        tags: [String] = []
    ) -> Recipe {
        Recipe(
            id: id,
            name: id,
            heroPhotoURL: "https://img.karta.app/\(id).jpg",
            totalMinutes: minutes,
            difficulty: difficulty,
            tags: tags,
            ingredients: [Ingredient(name: "x", quantity: "1")],
            steps: ["paso"]
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
            seen: [],
            filters: FeedFilters(maxMinutes: 30)
        )

        let ids = Set(feed.map(\.id))
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
            seen: [],
            filters: FeedFilters(maxDifficulty: .medium)
        )

        #expect(feed.map(\.id) == ["e", "m"])
    }

    @Test("requireOnePan keeps only recipes tagged one-pan")
    func filtersByOnePan() {
        let recipes = [
            recipe("one-pan-dish", tags: ["one-pan", "rapido"]),
            recipe("many-pans", tags: ["rapido"]),
        ]

        let feed = FeedQuery.feed(
            recipes: recipes,
            seen: [],
            filters: FeedFilters(requireOnePan: true)
        )

        #expect(feed.map(\.id) == ["one-pan-dish"])
    }

    @Test("Filters compose: time, difficulty and one-pan apply together")
    func filtersCompose() {
        let recipes = [
            recipe("match", minutes: 20, difficulty: .easy, tags: ["one-pan"]),
            recipe("too-slow", minutes: 90, difficulty: .easy, tags: ["one-pan"]),
            recipe("too-hard", minutes: 20, difficulty: .hard, tags: ["one-pan"]),
            recipe("many-pans", minutes: 20, difficulty: .easy, tags: []),
        ]

        let feed = FeedQuery.feed(
            recipes: recipes,
            seen: [],
            filters: FeedFilters(maxMinutes: 30, maxDifficulty: .medium, requireOnePan: true)
        )

        #expect(feed.map(\.id) == ["match"])
    }
}
