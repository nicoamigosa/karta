import Foundation
import KartaCore

/// Loads the seed catalogs packaged with KartaPresentation.
///
/// The bundle is injected so callers can provide another package bundle when
/// composing the presentation layer, while the default serves the app's
/// bundled seed. Decoding remains in KartaCore and is exercised independently
/// from this resource boundary.
public struct SeedResourceAdapter {

    public enum Error: Swift.Error, Equatable {
        case resourceMissing(String)
    }

    private let bundle: Bundle

    public init() {
        self.bundle = .module
    }

    public init(bundle: Bundle) {
        self.bundle = bundle
    }

    /// Loads and decodes the recipes bundled with KartaPresentation.
    public func loadRecipes() throws -> [Recipe] {
        try RecipeCatalog.decode(from: data(named: "seed-recipes"))
    }

    /// Loads and decodes the technique clips bundled with KartaPresentation.
    public func loadTechniqueClips() throws -> TechniqueClipLibrary {
        try TechniqueClipLibrary.decode(from: data(named: "seed-clips"))
    }

    private func data(named name: String) throws -> Data {
        guard let url = bundle.url(forResource: name, withExtension: "json") else {
            throw Error.resourceMissing(name)
        }
        return try Data(contentsOf: url)
    }
}
