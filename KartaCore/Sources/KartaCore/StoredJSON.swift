/// Opaque, lossless JSON values retained from an older schema. No domain rule
/// consumes them; unknown fields, array order and duplicates survive a save.
public enum StoredJSON: Codable, Equatable, Sendable {
    case object([String: StoredJSON])
    case array([StoredJSON])
    case string(String)
    case number(Double)
    case bool(Bool)
    case null

    public init(from decoder: any Decoder) throws {
        let value = try decoder.singleValueContainer()
        if value.decodeNil() { self = .null }
        else if let x = try? value.decode(Bool.self) { self = .bool(x) }
        else if let x = try? value.decode(String.self) { self = .string(x) }
        else if let x = try? value.decode(Double.self) { self = .number(x) }
        else if let x = try? value.decode([String: StoredJSON].self) { self = .object(x) }
        else { self = .array(try value.decode([StoredJSON].self)) }
    }

    public func encode(to encoder: any Encoder) throws {
        var value = encoder.singleValueContainer()
        switch self {
        case let .object(x): try value.encode(x)
        case let .array(x): try value.encode(x)
        case let .string(x): try value.encode(x)
        case let .number(x): try value.encode(x)
        case let .bool(x): try value.encode(x)
        case .null: try value.encodeNil()
        }
    }
}
