import Foundation

/// Access to the recipes the app ships with.
public enum RecipeCatalog {

    /// Decodes a recipe catalog from raw JSON. Pure: no I/O, easy to unit test.
    public static func decode(from data: Data) throws -> [Recipe] {
        try JSONDecoder().decode([Recipe].self, from: data)
    }
}
