import Testing
import KartaCore
import KartaPresentation

/// End-to-end checks against the real bundled seed catalog — the data the app
/// actually ships. Guards the critical intolerance-safety guarantee on real data
/// and the structured-step seam feeding cooking mode.
@Suite("Seed integration")
struct SeedIntegrationTests {

    @Test("Filtering an intolerance excludes every violating seed recipe")
    func intoleranceFilterOnRealCatalog() throws {
        let catalog = try SeedResourceAdapter().loadRecipes()

        // The test is only meaningful if the catalog actually contains the allergen.
        let glutenRecipes = catalog.filter { $0.contains.contains("gluten") }
        #expect(glutenRecipes.isEmpty == false, "seed must include gluten recipes to test against")

        let feed = FeedQuery.feed(
            recipes: catalog, seen: [], filters: FeedFilters(intolerances: ["gluten"])
        )

        #expect(feed.allSatisfy { !$0.contains.contains("gluten") })
        #expect(feed.count == catalog.count - glutenRecipes.count)
    }

    @Test("The feed orders the seed by popularity, most popular first")
    func feedOrdersByPopularity() throws {
        let catalog = try SeedResourceAdapter().loadRecipes()

        let feed = FeedQuery.feed(recipes: catalog, seen: [], filters: FeedFilters())
        let scores = feed.map(\.popularity)

        #expect(scores == scores.sorted(by: >))
    }

    @Test("Seed recipes carry structured steps that feed cooking mode")
    func structuredStepsFeedCooking() throws {
        let catalog = try SeedResourceAdapter().loadRecipes()

        // At least one step somewhere declares a timer and at least one a clip.
        let allSteps = catalog.flatMap(\.steps)
        #expect(allSteps.contains { $0.timerSeconds != nil })
        #expect(allSteps.contains { $0.clipID != nil })

        // A recipe builds a cooking session over its own steps.
        let recipe = try #require(catalog.first)
        #expect(recipe.cookingSession().steps == recipe.steps)
    }

    @Test("Every clip referenced by a seed step resolves in the seed clip library")
    func noDanglingClipReferences() throws {
        let catalog = try SeedResourceAdapter().loadRecipes()
        let library = try SeedResourceAdapter().loadTechniqueClips()

        for step in catalog.flatMap(\.steps) where step.clipID != nil {
            #expect(library.clip(for: step) != nil, "dangling clip id: \(step.clipID!)")
        }
    }
}
