import Foundation

/// The closed vocabulary of practical recipe tags (ADR 0013).
public enum PracticalTag: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
    case onePan = "one-pan"
    case oven
    case makeAhead = "make-ahead"
    case shareable

    public init?(rawValue: String) {
        switch rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "one-pan": self = .onePan
        case "oven": self = .oven
        case "make-ahead": self = .makeAhead
        case "shareable": self = .shareable
        default: return nil
        }
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        guard let tag = Self(rawValue: rawValue) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unknown practical tag '\(rawValue)'"
            )
        }
        self = tag
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
