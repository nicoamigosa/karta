import Foundation

/// The closed vocabulary of allergens understood by Karta.
public enum Allergen: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
    case dairy
    case egg
    case fish
    case gluten
    case nuts

    /// Accept catalog and profile input without making spelling part of the
    /// safety decision. The stored value remains the canonical lowercase term.
    public init?(rawValue: String) {
        switch rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "dairy": self = .dairy
        case "egg": self = .egg
        case "fish": self = .fish
        case "gluten": self = .gluten
        case "nuts": self = .nuts
        default: return nil
        }
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        guard let allergen = Self(rawValue: rawValue) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unknown allergen '\(rawValue)'"
            )
        }
        self = allergen
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
