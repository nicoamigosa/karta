import Foundation

public enum RecipeDecodingError: Error, Equatable, LocalizedError, Sendable {
    case missingAllergenReview(recipeID: String, recipeName: String)
    case unknownAllergen(recipeID: String, recipeName: String, value: String)
    case unknownTag(recipeID: String, recipeName: String, value: String)
    case emptyRecipeID(recipeName: String)
    case nonPositiveServings(recipeID: String, recipeName: String, value: Int)
    case nonPositiveTotalMinutes(recipeID: String, recipeName: String, value: Int)
    case nonPositiveTimerSeconds(recipeID: String, recipeName: String, stepIndex: Int, value: Int)
    case emptyRecipeName(recipeID: String)
    case emptyHeroPhotoURL(recipeID: String, recipeName: String)
    case invalidHeroPhotoReference(recipeID: String, recipeName: String, value: String)
    case emptyIngredients(recipeID: String, recipeName: String)
    case emptySteps(recipeID: String, recipeName: String)
    case emptyIngredientName(recipeID: String, recipeName: String, ingredientIndex: Int)
    case emptyIngredientQuantity(
        recipeID: String,
        recipeName: String,
        ingredientIndex: Int,
        ingredientName: String
    )
    case nonPositiveIngredientQuantity(
        recipeID: String,
        recipeName: String,
        ingredientIndex: Int,
        ingredientName: String,
        value: String
    )
    case emptyStepIngredientName(recipeID: String, recipeName: String, stepIndex: Int)
    case emptyStepIngredientQuantity(
        recipeID: String,
        recipeName: String,
        stepIndex: Int,
        ingredientName: String
    )
    case nonPositiveStepIngredientQuantity(
        recipeID: String,
        recipeName: String,
        stepIndex: Int,
        ingredientName: String,
        value: String
    )
    case emptyStepText(recipeID: String, recipeName: String, stepIndex: Int)
    case emptyStepClipID(recipeID: String, recipeName: String, stepIndex: Int)

    public var errorDescription: String? {
        switch self {
        case let .missingAllergenReview(recipeID, recipeName):
            return "Recipe '\(recipeID)' ('\(recipeName)') is missing its allergen review state"
        case let .unknownAllergen(recipeID, recipeName, value):
            return "Recipe '\(recipeID)' ('\(recipeName)') has unknown allergen '\(value)'"
        case let .unknownTag(recipeID, recipeName, value):
            return "Recipe '\(recipeID)' ('\(recipeName)') has unknown tag '\(value)'"
        case let .emptyRecipeID(recipeName):
            return "Recipe ('\(recipeName)') has an empty recipe id"
        case let .nonPositiveServings(recipeID, recipeName, value):
            return "Recipe '\(recipeID)' ('\(recipeName)') has non-positive servings '\(value)'"
        case let .nonPositiveTotalMinutes(recipeID, recipeName, value):
            return "Recipe '\(recipeID)' ('\(recipeName)') has non-positive total minutes '\(value)'"
        case let .nonPositiveTimerSeconds(recipeID, recipeName, stepIndex, value):
            return "Recipe '\(recipeID)' ('\(recipeName)') step \(stepIndex) has non-positive timer seconds '\(value)'"
        case let .emptyRecipeName(recipeID):
            return "Recipe '\(recipeID)' has an empty recipe name"
        case let .emptyHeroPhotoURL(recipeID, recipeName):
            return "Recipe '\(recipeID)' ('\(recipeName)') has an empty hero photo URL"
        case let .invalidHeroPhotoReference(recipeID, recipeName, value):
            return "Recipe '\(recipeID)' ('\(recipeName)') has invalid hero photo reference '\(value)'"
        case let .emptyIngredients(recipeID, recipeName):
            return "Recipe '\(recipeID)' ('\(recipeName)') has no ingredients"
        case let .emptySteps(recipeID, recipeName):
            return "Recipe '\(recipeID)' ('\(recipeName)') has no steps"
        case let .emptyIngredientName(recipeID, recipeName, ingredientIndex):
            return "Recipe '\(recipeID)' ('\(recipeName)') ingredient \(ingredientIndex) has an empty name"
        case let .emptyIngredientQuantity(recipeID, recipeName, ingredientIndex, ingredientName):
            return "Recipe '\(recipeID)' ('\(recipeName)') ingredient \(ingredientIndex) '\(ingredientName)' has an empty quantity"
        case let .nonPositiveIngredientQuantity(recipeID, recipeName, ingredientIndex, ingredientName, value):
            return "Recipe '\(recipeID)' ('\(recipeName)') ingredient \(ingredientIndex) '\(ingredientName)' has non-positive quantity '\(value)'"
        case let .emptyStepIngredientName(recipeID, recipeName, stepIndex):
            return "Recipe '\(recipeID)' ('\(recipeName)') step \(stepIndex) has an ingredient with an empty name"
        case let .emptyStepIngredientQuantity(recipeID, recipeName, stepIndex, ingredientName):
            return "Recipe '\(recipeID)' ('\(recipeName)') step \(stepIndex) ingredient '\(ingredientName)' has an empty quantity"
        case let .nonPositiveStepIngredientQuantity(recipeID, recipeName, stepIndex, ingredientName, value):
            return "Recipe '\(recipeID)' ('\(recipeName)') step \(stepIndex) ingredient '\(ingredientName)' has non-positive quantity '\(value)'"
        case let .emptyStepText(recipeID, recipeName, stepIndex):
            return "Recipe '\(recipeID)' ('\(recipeName)') step \(stepIndex) has empty text"
        case let .emptyStepClipID(recipeID, recipeName, stepIndex):
            return "Recipe '\(recipeID)' ('\(recipeName)') step \(stepIndex) has an empty technique clip id"
        }
    }
}

/// The editor's allergen decision for a recipe.
///
/// An unreviewed recipe has no allergen set. Keeping that state as a separate
/// case prevents it from being treated as a reviewed recipe with no allergens.
public enum AllergenReview: Equatable, Sendable {
    case reviewed(Set<Allergen>)
    case unreviewed
}

/// A cookable recipe: the foundation domain model every feature builds on.
public struct Recipe: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let heroPhoto: MediaReference
    public let totalMinutes: Int
    public let difficulty: Difficulty
    public let servings: Int
    public let tags: [RecipeTag]
    public let ingredients: [Ingredient]
    /// Ordered, structured steps. Each step is self-contained and may carry the
    /// exact ingredient it needs, a timer, and a reusable technique clip. Decodes
    /// backward-compatibly from a bare string (text-only step).
    public let steps: [CookingStep]
    /// The editor's explicit allergen review decision.
    public let allergenReview: AllergenReview
    /// The date the editor published this recipe for feed freshness ranking.
    public let editorialDate: Date
    /// Precalculated popularity score; the feed uses this after freshness and fit.
    public let popularity: Int

    public init(
        id: String,
        name: String,
        heroPhoto: MediaReference,
        totalMinutes: Int,
        difficulty: Difficulty,
        servings: Int,
        tags: [RecipeTag],
        ingredients: [Ingredient],
        steps: [CookingStep],
        allergenReview: AllergenReview,
        editorialDate: Date = .distantPast,
        popularity: Int = 0
    ) {
        self.id = id
        self.name = name
        self.heroPhoto = heroPhoto
        self.totalMinutes = totalMinutes
        self.difficulty = difficulty
        self.servings = servings
        self.tags = tags
        self.ingredients = ingredients
        self.steps = steps
        self.allergenReview = allergenReview
        self.editorialDate = editorialDate
        self.popularity = popularity
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        guard !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw RecipeDecodingError.emptyRecipeID(recipeName: name)
        }
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw RecipeDecodingError.emptyRecipeName(recipeID: id)
        }
        let rawHeroPhoto = try c.decode(String.self, forKey: .heroPhotoURL)
        guard !rawHeroPhoto.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw RecipeDecodingError.emptyHeroPhotoURL(
                recipeID: id,
                recipeName: name
            )
        }
        do {
            heroPhoto = try MediaReference(validating: rawHeroPhoto)
        } catch {
            throw RecipeDecodingError.invalidHeroPhotoReference(
                recipeID: id,
                recipeName: name,
                value: rawHeroPhoto
            )
        }
        totalMinutes = try c.decode(Int.self, forKey: .totalMinutes)
        guard totalMinutes > 0 else {
            throw RecipeDecodingError.nonPositiveTotalMinutes(
                recipeID: id,
                recipeName: name,
                value: totalMinutes
            )
        }
        difficulty = try c.decode(Difficulty.self, forKey: .difficulty)
        servings = try c.decode(Int.self, forKey: .servings)
        guard servings > 0 else {
            throw RecipeDecodingError.nonPositiveServings(
                recipeID: id,
                recipeName: name,
                value: servings
            )
        }
        let recipeID = id
        let recipeName = name
        tags = try c.decode([String].self, forKey: .tags).map { rawValue in
            guard let tag = RecipeTag(rawValue: rawValue) else {
                throw RecipeDecodingError.unknownTag(
                    recipeID: recipeID,
                    recipeName: recipeName,
                    value: rawValue
                )
            }
            return tag
        }
        ingredients = try c.decode([Ingredient].self, forKey: .ingredients)
        guard !ingredients.isEmpty else {
            throw RecipeDecodingError.emptyIngredients(recipeID: id, recipeName: name)
        }
        for (index, ingredient) in ingredients.enumerated() {
            guard !ingredient.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw RecipeDecodingError.emptyIngredientName(
                    recipeID: id,
                    recipeName: name,
                    ingredientIndex: index
                )
            }
            try validateIngredientQuantity(
                ingredient,
                recipeID: id,
                recipeName: name,
                location: .recipe(index: index)
            )
        }
        steps = try c.decode([CookingStep].self, forKey: .steps)
        guard !steps.isEmpty else {
            throw RecipeDecodingError.emptySteps(recipeID: id, recipeName: name)
        }
        for (index, step) in steps.enumerated() {
            guard !step.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw RecipeDecodingError.emptyStepText(
                    recipeID: id,
                    recipeName: name,
                    stepIndex: index
                )
            }
            if step.clipID?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true {
                throw RecipeDecodingError.emptyStepClipID(
                    recipeID: id,
                    recipeName: name,
                    stepIndex: index
                )
            }
            if let timerSeconds = step.timerSeconds, timerSeconds <= 0 {
                throw RecipeDecodingError.nonPositiveTimerSeconds(
                    recipeID: id,
                    recipeName: name,
                    stepIndex: index,
                    value: timerSeconds
                )
            }
            if let ingredient = step.ingredient {
                guard !ingredient.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    throw RecipeDecodingError.emptyStepIngredientName(
                        recipeID: id,
                        recipeName: name,
                        stepIndex: index
                    )
                }
                try validateIngredientQuantity(
                    ingredient,
                    recipeID: id,
                    recipeName: name,
                    location: .step(index: index)
                )
            }
        }
        guard c.contains(.allergenReview) else {
            throw RecipeDecodingError.missingAllergenReview(
                recipeID: recipeID,
                recipeName: recipeName
            )
        }
        if try c.decodeNil(forKey: .allergenReview) {
            allergenReview = .unreviewed
        } else {
            let rawContains = try c.decode([String].self, forKey: .allergenReview)
            allergenReview = .reviewed(try Set(rawContains.map { rawValue in
                guard let allergen = Allergen(rawValue: rawValue) else {
                    throw RecipeDecodingError.unknownAllergen(
                        recipeID: recipeID,
                        recipeName: recipeName,
                        value: rawValue
                    )
                }
                return allergen
            }))
        }
        // Recipes constructed before editorial dates existed remain valid and
        // intentionally rank as the oldest content until the catalog supplies one.
        editorialDate = try c.decodeIfPresent(Date.self, forKey: .editorialDate) ?? .distantPast
        popularity = try c.decodeIfPresent(Int.self, forKey: .popularity) ?? 0
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(heroPhoto.rawValue, forKey: .heroPhotoURL)
        try c.encode(totalMinutes, forKey: .totalMinutes)
        try c.encode(difficulty, forKey: .difficulty)
        try c.encode(servings, forKey: .servings)
        try c.encode(tags, forKey: .tags)
        try c.encode(ingredients, forKey: .ingredients)
        try c.encode(steps, forKey: .steps)
        switch allergenReview {
        case let .reviewed(allergens):
            try c.encode(allergens.map(\.rawValue).sorted(), forKey: .allergenReview)
        case .unreviewed:
            try c.encodeNil(forKey: .allergenReview)
        }
        try c.encode(editorialDate, forKey: .editorialDate)
        try c.encode(popularity, forKey: .popularity)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case heroPhotoURL
        case totalMinutes
        case difficulty
        case servings
        case tags
        case ingredients
        case steps
        case allergenReview = "contains"
        case editorialDate
        case popularity
    }
}

/// An ingredient line shown both in the detail view and, self-contained,
/// inside each cooking step.
public struct Ingredient: Codable, Equatable, Sendable {
    public let name: String
    public let quantity: String

    public init(name: String, quantity: String) {
        self.name = name
        self.quantity = quantity
    }
}

private enum IngredientQuantityLocation {
    case recipe(index: Int)
    case step(index: Int)
}

private func validateIngredientQuantity(
    _ ingredient: Ingredient,
    recipeID: String,
    recipeName: String,
    location: IngredientQuantityLocation
) throws {
    let quantity = ingredient.quantity.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !quantity.isEmpty else {
        switch location {
        case let .recipe(index):
            throw RecipeDecodingError.emptyIngredientQuantity(
                recipeID: recipeID,
                recipeName: recipeName,
                ingredientIndex: index,
                ingredientName: ingredient.name
            )
        case let .step(index):
            throw RecipeDecodingError.emptyStepIngredientQuantity(
                recipeID: recipeID,
                recipeName: recipeName,
                stepIndex: index,
                ingredientName: ingredient.name
            )
        }
    }

    let numericPrefix = String(quantity.prefix { character in
        character == "." || character == "-" || character == "+"
            || character.isNumber
    })
    if let numericValue = Double(numericPrefix), numericValue <= 0 {
        switch location {
        case let .recipe(index):
            throw RecipeDecodingError.nonPositiveIngredientQuantity(
                recipeID: recipeID,
                recipeName: recipeName,
                ingredientIndex: index,
                ingredientName: ingredient.name,
                value: ingredient.quantity
            )
        case let .step(index):
            throw RecipeDecodingError.nonPositiveStepIngredientQuantity(
                recipeID: recipeID,
                recipeName: recipeName,
                stepIndex: index,
                ingredientName: ingredient.name,
                value: ingredient.quantity
            )
        }
    }
}

public enum Difficulty: String, Codable, Equatable, Sendable, Comparable, CaseIterable {
    case easy
    case medium
    case hard

    private var rank: Int { Self.allCases.firstIndex(of: self)! }

    public static func < (lhs: Difficulty, rhs: Difficulty) -> Bool {
        lhs.rank < rhs.rank
    }
}
