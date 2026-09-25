import Testing
import Foundation
import KartaCore
@testable import KartaPresentation

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

    @Test("Every local hero photo in the seed resolves to a file bundled with the app")
    func seedHeroPhotosResolveToBundledFiles() throws {
        let adapter = SeedResourceAdapter()
        let resolver = MediaResolver(manifest: try adapter.loadMediaManifest(), baseURL: nil)
        let localPhotos = try adapter.loadRecipes().map(\.heroPhoto).filter {
            if case .local = $0 { return true } else { return false }
        }

        #expect(!localPhotos.isEmpty)
        for photo in localPhotos {
            guard case let .bundle(resource) = try resolver.resolve(photo) else {
                Issue.record("\(photo.rawValue) did not resolve to a bundle resource")
                continue
            }
            #expect(Bundle.module.url(forResource: resource, withExtension: nil) != nil,
                    "\(resource) is not in the bundle")
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
