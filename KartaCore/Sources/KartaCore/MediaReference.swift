import Foundation

/// The locations a catalog may use for media.
///
/// A remote reference is deliberately restricted to HTTPS. Local references
/// are keys in the presentation-layer asset manifest; they do not assume a
/// particular bundle or file name.
public enum MediaReference: Codable, Equatable, Hashable, Sendable {
    case remote(URL)
    case local(String)
    case relative(String)

    public enum ValidationError: Error, Equatable, LocalizedError, Sendable {
        case empty
        case invalid(String)
        case unsupportedScheme(String)

        public var errorDescription: String? {
            switch self {
            case .empty:
                return "Media reference is empty"
            case let .invalid(value):
                return "Media reference '\(value)' is invalid"
            case let .unsupportedScheme(scheme):
                return "Media reference scheme '\(scheme)' is not supported"
            }
        }
    }

    /// Decode a catalog value such as `https://...`, `local:asset-id`, or
    /// `relative:clips/foo.mp4`.
    public init(validating rawValue: String) throws {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { throw ValidationError.empty }

        if value.hasPrefix("local:") {
            let name = String(value.dropFirst("local:".count))
            guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw ValidationError.invalid(rawValue)
            }
            self = .local(name)
            return
        }

        if value.hasPrefix("relative:") {
            let path = String(value.dropFirst("relative:".count))
            guard !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !path.hasPrefix("/") else {
                throw ValidationError.invalid(rawValue)
            }
            self = .relative(path)
            return
        }

        guard let url = URL(string: value),
              let scheme = url.scheme?.lowercased() else {
            throw ValidationError.invalid(rawValue)
        }
        guard scheme == "https" else {
            throw ValidationError.unsupportedScheme(scheme)
        }
        guard url.host != nil else { throw ValidationError.invalid(rawValue) }
        self = .remote(url)
    }

    public init(from decoder: any Decoder) throws {
        try self.init(validating: decoder.singleValueContainer().decode(String.self))
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    /// The catalog representation used when encoding a reference.
    public var rawValue: String {
        switch self {
        case let .remote(url):
            return url.absoluteString
        case let .local(name):
            return "local:\(name)"
        case let .relative(path):
            return "relative:\(path)"
        }
    }

}
