import Foundation

/// The closed vocabulary for recipe diets. Vegan recipes also satisfy a
/// vegetarian filter, but diet labels never participate in safety checks.
public enum Diet: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
    case vegetarian
    case vegan

    public init?(rawValue: String) {
        switch rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "vegetarian": self = .vegetarian
        case "vegan": self = .vegan
        default: return nil
        }
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        guard let diet = Self(rawValue: rawValue) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unknown Diet '\(rawValue)'"
            )
        }
        self = diet
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
