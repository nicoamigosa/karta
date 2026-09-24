import Testing
import Foundation
import KartaCore
import KartaPresentation

/// Checks that the bundled seeds load through the resource boundary and agree
/// with each other.
@Suite("Seed integration")
struct SeedIntegrationTests {

    @Test("Every clip a seed step references exists in the bundled clip catalog")
    func seedClipReferencesResolve() throws {
        let adapter = SeedResourceAdapter()
        let library = try adapter.loadTechniqueClips()
        let steps = try adapter.loadRecipes().flatMap(\.steps).filter { $0.clipID != nil }

        #expect(!steps.isEmpty)
        #expect(steps.allSatisfy { library.clip(for: $0) != nil })
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
