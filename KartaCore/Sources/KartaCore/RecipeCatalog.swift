import Foundation

public enum RecipeCatalogDecodingError: Error, Equatable, LocalizedError, Sendable {
    case duplicateRecipeID(String)
    case leftoversPillDoesNotFit(recipeID: String, ingredientID: String)

    public var errorDescription: String? {
        switch self {
        case let .leftoversPillDoesNotFit(recipeID, ingredientID):
            return "Recipe '\(recipeID)' has a leftovers pill that does not fit: '\(ingredientID)'"
        case let .duplicateRecipeID(id):
            return "Recipe catalog contains duplicate recipe id '\(id)'"
        }
    }
}

/// Access to the recipes the app ships with.
public enum RecipeCatalog {

    /// Decodes a recipe catalog from raw JSON. Pure: no I/O, easy to unit test.
    public static func decode(from data: Data) throws -> [Recipe] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let recipes = try decoder.decode([Recipe].self, from: data)
        var ids = Set<String>()
        for recipe in recipes where !ids.insert(recipe.id).inserted {
            throw RecipeCatalogDecodingError.duplicateRecipeID(recipe.id)
        }
        try LeftoversPillFit.validate(recipes)
        return recipes
    }
}
