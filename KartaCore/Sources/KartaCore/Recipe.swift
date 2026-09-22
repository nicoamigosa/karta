import Foundation

public enum RecipeDecodingError: Error, Equatable, LocalizedError, Sendable {
    case missingAllergenReview(recipeID: String, recipeName: String)
    case unknownAllergen(recipeID: String, recipeName: String, value: String)

    public var errorDescription: String? {
        switch self {
        case let .missingAllergenReview(recipeID, recipeName):
            return "Recipe '\(recipeID)' ('\(recipeName)') is missing its allergen review state"
        case let .unknownAllergen(recipeID, recipeName, value):
            return "Recipe '\(recipeID)' ('\(recipeName)') has unknown allergen '\(value)'"
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
    public let heroPhotoURL: String
    public let totalMinutes: Int
    public let difficulty: Difficulty
    public let tags: [String]
    public let ingredients: [Ingredient]
    /// Ordered, structured steps. Each step is self-contained and may carry the
    /// exact ingredient it needs, a timer, and a reusable technique clip. Decodes
    /// backward-compatibly from a bare string (text-only step).
    public let steps: [CookingStep]
    /// The editor's explicit allergen review decision.
    public let allergenReview: AllergenReview
    /// Precalculated popularity score; the feed orders by this (higher first).
    public let popularity: Int

    public init(
        id: String,
        name: String,
        heroPhotoURL: String,
        totalMinutes: Int,
        difficulty: Difficulty,
        tags: [String],
        ingredients: [Ingredient],
        steps: [CookingStep],
        allergenReview: AllergenReview,
        popularity: Int = 0
    ) {
        self.id = id
        self.name = name
        self.heroPhotoURL = heroPhotoURL
        self.totalMinutes = totalMinutes
        self.difficulty = difficulty
        self.tags = tags
        self.ingredients = ingredients
        self.steps = steps
        self.allergenReview = allergenReview
        self.popularity = popularity
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        heroPhotoURL = try c.decode(String.self, forKey: .heroPhotoURL)
        totalMinutes = try c.decode(Int.self, forKey: .totalMinutes)
        difficulty = try c.decode(Difficulty.self, forKey: .difficulty)
        tags = try c.decode([String].self, forKey: .tags)
        ingredients = try c.decode([Ingredient].self, forKey: .ingredients)
        steps = try c.decode([CookingStep].self, forKey: .steps)
        let recipeID = id
        let recipeName = name
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
        popularity = try c.decodeIfPresent(Int.self, forKey: .popularity) ?? 0
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(heroPhotoURL, forKey: .heroPhotoURL)
        try c.encode(totalMinutes, forKey: .totalMinutes)
        try c.encode(difficulty, forKey: .difficulty)
        try c.encode(tags, forKey: .tags)
        try c.encode(ingredients, forKey: .ingredients)
        try c.encode(steps, forKey: .steps)
        switch allergenReview {
        case let .reviewed(allergens):
            try c.encode(allergens.map(\.rawValue).sorted(), forKey: .allergenReview)
        case .unreviewed:
            try c.encodeNil(forKey: .allergenReview)
        }
        try c.encode(popularity, forKey: .popularity)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case heroPhotoURL
        case totalMinutes
        case difficulty
        case tags
        case ingredients
        case steps
        case allergenReview = "contains"
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

public enum Difficulty: String, Codable, Equatable, Sendable, Comparable, CaseIterable {
    case easy
    case medium
    case hard

    private var rank: Int { Self.allCases.firstIndex(of: self)! }

    public static func < (lhs: Difficulty, rhs: Difficulty) -> Bool {
        lhs.rank < rhs.rank
    }
}
