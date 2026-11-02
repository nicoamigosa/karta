import Foundation
import Testing
import KartaCore

@Suite("Gusto from behavior")
struct GustoTests {
    private let now = Date(timeIntervalSince1970: 1_000_000)
    private var clock: GustoClock { GustoClock(now: now) }

    private func recipe(
        _ id: String, course: Course = .dinner, diets: Set<Diet> = [],
        tags: Set<PracticalTag> = [], ingredient: String = "Water",
        minutes: Int = 15, allergens: Set<Allergen> = [], popularity: Int = 0
    ) -> Recipe {
        Recipe(id: id, name: id, heroPhoto: .local("test"), totalMinutes: minutes,
               difficulty: .easy, servings: 4, primaryCourse: course, diets: diets,
               practicalTags: tags, ingredients: [Ingredient(name: ingredient, quantity: "1 cup")],
               steps: ["Cook"], allergenReview: .reviewed(allergens), popularity: popularity)
    }

    @Test("Each affinity signal ranks safe filtered candidates without crossing the Frontera",
          arguments: 0..<4)
    func affinityAndBoundaries(feature: Int) {
        let source = recipe("source", course: .breakfast, diets: [.vegan], tags: [.oven],
                            ingredient: "Rice", allergens: [.dairy])
        let near = recipe("near", course: feature == 0 ? .breakfast : .dinner,
                          diets: feature == 1 ? [.vegan] : [],
                          tags: feature == 2 ? [.oven] : [],
                          ingredient: feature == 3 ? "rice" : "Water")
        let far = recipe("far", popularity: 100)
        let seen = recipe("seen", course: .breakfast, diets: [.vegan], tags: [.oven], ingredient: "Rice")
        let slow = recipe("slow", course: .breakfast, diets: [.vegan], tags: [.oven],
                          ingredient: "Rice", minutes: 60)
        let catalog = [far, near, source, seen, slow]
        let history = ViewHistory(
            entries: [ViewEntry(recipeID: "seen", date: now)],
            openings: [OpenEntry(recipeID: "source", date: now)])
        let feed = FeedQuery.feed(
            recipes: catalog, views: history.entries, recentWindow: 86_400, clock: clock,
            filters: FeedFilters(intolerances: [.dairy], maxMinutes: 30),
            tastePreferences: TastePreferences(recipes: catalog, history: history, savedIDs: ["source"]))
        #expect(feed.newRecipes.map(\.id) == ["near", "far"])
        #expect(feed.alreadySeenRecipes.map(\.id) == ["seen"])
        #expect(feed.recipes.count == 3)
    }

    @Test("A Vista without an Apertura is a soft negative and an Apertura reverses it")
    func passingWithoutOpening() {
        let source = recipe("source", course: .breakfast, ingredient: "Rice", minutes: 60)
        let near = recipe("near", course: .breakfast, ingredient: "Rice", popularity: 100)
        let far = recipe("far")
        let catalog = [near, far, source]
        var history = ViewHistory(entries: [ViewEntry(recipeID: "source", date: now)])
        func feed(_ history: ViewHistory) -> [String] {
            FeedQuery.feed(
                recipes: catalog, views: [], recentWindow: 86_400, clock: clock,
                filters: FeedFilters(maxMinutes: 30),
                tastePreferences: TastePreferences(recipes: catalog, history: history)).recipes.map(\.id)
        }
        #expect(feed(ViewHistory()) == ["near", "far"])
        #expect(feed(history) == ["far", "near"])
        history.recordOpen(recipeID: "source", at: now)
        #expect(feed(history) == ["near", "far"])
        #expect(feed(history) == feed(ViewHistory(openings: history.openings)))
    }
}

private struct GustoClock: KartaClock {
    let now: Date
}
