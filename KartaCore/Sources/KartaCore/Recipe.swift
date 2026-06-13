import Foundation

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
    /// Allergen / intolerance tags this recipe contains (e.g. "gluten", "lactose").
    /// Used by the feed engine to enforce intolerance safety filtering.
    public let contains: [String]
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
        contains: [String] = [],
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
        self.contains = contains
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
        contains = try c.decodeIfPresent([String].self, forKey: .contains) ?? []
        popularity = try c.decodeIfPresent(Int.self, forKey: .popularity) ?? 0
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
