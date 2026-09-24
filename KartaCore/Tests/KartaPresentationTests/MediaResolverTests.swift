import Foundation
import Testing
import KartaCore
import KartaPresentation

@Suite("Media resolver")
struct MediaResolverTests {

    @Test("The resolver handles HTTPS, local manifest and relative references")
    func resolvesSupportedReferences() throws {
        let resolver = MediaResolver(
            manifest: MediaAssetManifest(["hero": "photos/hero.jpg"]),
            baseURL: URL(string: "https://cdn.karta.app/media/")!
        )

        #expect(try resolver.resolve(.remote(URL(string: "https://img.karta.app/hero.jpg")!))
            == .remote(URL(string: "https://img.karta.app/hero.jpg")!))
        #expect(try resolver.resolve(.local("hero")) == .bundle(resource: "photos/hero.jpg"))
        #expect(try resolver.resolve(.relative("clips/chop.mp4"))
            == .remote(URL(string: "https://cdn.karta.app/media/clips/chop.mp4")!))
    }

    @Test("A local reference missing from the injected manifest is observable")
    func missingManifestEntryFails() throws {
        let resolver = MediaResolver(manifest: MediaAssetManifest([:]), baseURL: nil)

        do {
            _ = try resolver.resolve(.local("missing"))
            Issue.record("Expected the missing asset to fail resolution")
        } catch let error as MediaResolutionError {
            #expect(error == .missingAsset("missing"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}
