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

    @Test("The public adapter rejects the legacy recipe catalog before editorial migration")
    func rejectsLegacySeed() throws {
        do {
            _ = try SeedResourceAdapter().loadRecipes()
            Issue.record("Expected the legacy seed to be rejected")
        } catch let error as RecipeDecodingError {
            Issue.record("Unexpected typed recipe error: \(error)")
        } catch let error as DecodingError {
            guard case let .keyNotFound(key, _) = error else {
                Issue.record("Unexpected decoding error: \(error)")
                return
            }
            #expect(key.stringValue == "servings")
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}
