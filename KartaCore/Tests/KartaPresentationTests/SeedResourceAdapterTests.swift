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

    @Test("The public adapter loads the injected media asset manifest")
    func loadsMediaManifest() throws {
        let manifest = try SeedResourceAdapter().loadMediaManifest()

        #expect(manifest.resourceName(for: "clips/cuajar-tortilla.mp4")
            == "clips/cuajar-tortilla.mp4")
    }

    @Test("The public adapter loads the bundled recipe catalog")
    func loadsBundledRecipes() throws {
        let recipes = try SeedResourceAdapter().loadRecipes()

        #expect(recipes.map(\.id).contains("tortilla-de-papa"))
    }
}
