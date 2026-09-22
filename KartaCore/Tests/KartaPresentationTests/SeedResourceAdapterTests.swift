import Foundation
import Testing
import KartaCore
import KartaPresentation

@Suite("Seed resource adapter")
struct SeedResourceAdapterTests {

    @Test("The public adapter loads both bundled seed catalogs")
    func loadsBundledSeeds() throws {
        let adapter = SeedResourceAdapter()

        let recipes = try adapter.loadRecipes()
        let clips = try adapter.loadTechniqueClips()

        #expect(!recipes.isEmpty)
        #expect(clips.clip(for: CookingStep(text: "", clipID: "cuajar-tortilla")) != nil)
        #expect(recipes.allSatisfy { !$0.ingredients.isEmpty && !$0.steps.isEmpty })
    }
}
