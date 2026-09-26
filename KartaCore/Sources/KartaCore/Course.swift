import Foundation

/// The closed vocabulary of recipe Courses (ADR 0013).
public enum Course: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
    case breakfast
    case lunch
    case dinner
    case dessert

    public init?(rawValue: String) {
        switch rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "breakfast": self = .breakfast
        case "lunch": self = .lunch
        case "dinner": self = .dinner
        case "dessert": self = .dessert
        default: return nil
        }
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        guard let course = Self(rawValue: rawValue) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unknown Course '\(rawValue)'"
            )
        }
        self = course
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
