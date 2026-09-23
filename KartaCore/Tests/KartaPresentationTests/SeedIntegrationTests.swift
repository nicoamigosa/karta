import Testing
import Foundation
import KartaCore
import KartaPresentation

/// Checks the resource boundary while the legacy seed is awaiting the
/// editorial rewrite in issue #32.
@Suite("Seed integration")
struct SeedIntegrationTests {

    @Test("The legacy seed is rejected before editorial migration")
    func legacySeedFailsLoudly() throws {
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

    @Test("The bundled clip catalog remains loadable")
    func clipsRemainLoadable() throws {
        let library = try SeedResourceAdapter().loadTechniqueClips()
        let clip = try #require(library.clip(for: CookingStep(text: "", clipID: "cuajar-tortilla")))
        #expect(clip.id == "cuajar-tortilla")
    }

    @Test("A bundled clip source resolves through the packaged manifest")
    func bundledClipSourceResolves() throws {
        let adapter = SeedResourceAdapter()
        let library = try adapter.loadTechniqueClips()
        let manifest = try adapter.loadMediaManifest()
        let clip = try #require(library.clip(for: CookingStep(text: "", clipID: "cuajar-tortilla")))

        let resolved = try MediaResolver(manifest: manifest, baseURL: nil).resolve(clip.source)

        #expect(resolved == .bundle(resource: "clips/cuajar-tortilla.mp4"))
    }
}
