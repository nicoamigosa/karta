import Testing
import KartaCore
import KartaPresentation

/// Checks that the bundled seeds load through the resource boundary and agree
/// with each other.
@Suite("Seed integration")
struct SeedIntegrationTests {

    @Test("The bundled clip catalog remains loadable")
    func clipsRemainLoadable() throws {
        let library = try SeedResourceAdapter().loadTechniqueClips()
        let clip = try #require(library.clip(for: CookingStep(text: "", clipID: "cuajar-tortilla")))
        #expect(clip.id == "cuajar-tortilla")
    }
}
