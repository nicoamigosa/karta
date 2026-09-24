import Foundation

/// The closed, English vocabulary of recipe tags. Like allergens, tags are
/// data, never presentation: a term outside this list invalidates the recipe
/// instead of being carried along as free text (ADR 0005).
public enum RecipeTag: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
    case onePan = "one-pan"
    case vegetarian
    case quick
    case classic
    case hearty
    case fresh
    case breakfast
    case sweet
    case oven

    /// Accept catalog input without making spelling part of the decision. The
    /// stored value remains the canonical lowercase term.
    public init?(rawValue: String) {
        let normalized = rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard let tag = Self.allCases.first(where: { $0.canonical == normalized }) else {
            return nil
        }
        self = tag
    }

    private var canonical: String {
        switch self {
        case .onePan: "one-pan"
        case .vegetarian: "vegetarian"
        case .quick: "quick"
        case .classic: "classic"
        case .hearty: "hearty"
        case .fresh: "fresh"
        case .breakfast: "breakfast"
        case .sweet: "sweet"
        case .oven: "oven"
        }
    }
}
