import Foundation
import Testing
import KartaCore
import KartaPresentation

@Suite("Seed resource adapter")
struct SeedResourceAdapterTests {

    @Test("The public adapter loads the bundled clip catalog")
    func loadsBundledClips() throws {
        let adapter = SeedResourceAdapter()

        let clips = try adapter.loadTechniqueClips()

        let clip = try #require(clips.clip(for: CookingStep(text: "", clipID: "cuajar-tortilla")))
        #expect(clip.id == "cuajar-tortilla")
    }

    @Test("The public adapter loads the bundled recipe catalog")
    func loadsBundledRecipes() throws {
        let recipes = try SeedResourceAdapter().loadRecipes()

        #expect(recipes.count == 8)
        let tortilla = try #require(recipes.first { $0.id == "tortilla-de-papa" })
        #expect(tortilla.id == "tortilla-de-papa")
    }
}
