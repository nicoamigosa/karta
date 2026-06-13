import Foundation

/// Access to the recipes the app ships with.
public enum RecipeCatalog {

    public enum Error: Swift.Error {
        case seedResourceMissing
    }

    /// Decodes a recipe catalog from raw JSON. Pure: no I/O, easy to unit test.
    public static func decode(from data: Data) throws -> [Recipe] {
        try JSONDecoder().decode([Recipe].self, from: data)
    }

    /// Loads the bundled seed catalog that ships inside the package.
    public static func seed() throws -> [Recipe] {
        guard let url = Bundle.module.url(forResource: "seed-recipes", withExtension: "json") else {
            throw Error.seedResourceMissing
        }
        return try decode(from: Data(contentsOf: url))
    }
}
