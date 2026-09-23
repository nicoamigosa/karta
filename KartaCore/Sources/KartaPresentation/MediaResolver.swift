import Foundation
import KartaCore

/// The presentation-owned mapping from a catalog asset key to a bundle
/// resource name. It is injected so tests and the eventual app shell can use
/// different manifests without changing Core models.
public struct MediaAssetManifest: Codable, Equatable, Sendable {
    public let assets: [String: String]

    public init(_ assets: [String: String]) {
        self.assets = assets
    }

    public init(assets: [String: String]) {
        self.init(assets)
    }

    public init(entries: [String: String]) {
        self.init(entries)
    }

    public init(from decoder: any Decoder) throws {
        if let container = try? decoder.container(keyedBy: CodingKeys.self),
           let assets = try container.decodeIfPresent([String: String].self, forKey: .assets) {
            self.assets = assets
            return
        }
        self.assets = try decoder.singleValueContainer().decode([String: String].self)
    }

    public func resourceName(for key: String) -> String? {
        assets[key]
    }

    private enum CodingKeys: String, CodingKey {
        case assets
    }
}

/// Compatibility spelling for callers that use the shorter domain term.
public typealias AssetManifest = MediaAssetManifest

public enum MediaResolutionError: Error, Equatable, Hashable, LocalizedError, Sendable {
    case missingAsset(String)
    case missingBaseURL(String)
    case invalidReference(String)

    public var errorDescription: String? {
        switch self {
        case let .missingAsset(key):
            return "Media asset '\(key)' is missing from the manifest"
        case let .missingBaseURL(path):
            return "No base URL was provided for media path '\(path)'"
        case let .invalidReference(value):
            return "Media reference '\(value)' cannot be resolved"
        }
    }
}

/// The source the iOS shell can hand to Bundle or its network/media stack.
/// Presentation deliberately does not load bytes or import AVFoundation.
public enum ResolvedMedia: Equatable, Hashable, Sendable {
    case remote(URL)
    case bundle(resource: String)

    public static func bundle(name: String) -> Self {
        .bundle(resource: name)
    }
}

public typealias ResolvedMediaSource = ResolvedMedia

/// Resolves Core references using injected presentation configuration.
public struct MediaResolver: Sendable {
    public let manifest: MediaAssetManifest
    public let baseURL: URL?

    public init(manifest: MediaAssetManifest, baseURL: URL?) {
        self.manifest = manifest
        self.baseURL = baseURL
    }

    public init(assetManifest: MediaAssetManifest, baseURL: URL?) {
        self.init(manifest: assetManifest, baseURL: baseURL)
    }

    public init(manifest: [String: String], baseURL: URL?) {
        self.init(manifest: MediaAssetManifest(manifest), baseURL: baseURL)
    }

    public func resolve(_ reference: MediaReference) throws -> ResolvedMedia {
        switch reference {
        case let .remote(url):
            guard url.scheme?.lowercased() == "https", url.host != nil else {
                throw MediaResolutionError.invalidReference(reference.rawValue)
            }
            return .remote(url)

        case let .local(key):
            guard let resource = manifest.resourceName(for: key),
                  !resource.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw MediaResolutionError.missingAsset(key)
            }
            return .bundle(resource: resource)

        case let .relative(path):
            guard !path.isEmpty, !path.hasPrefix("/"),
                  !path.contains("://"),
                  let baseURL else {
                throw baseURL == nil
                    ? MediaResolutionError.missingBaseURL(path)
                    : MediaResolutionError.invalidReference(reference.rawValue)
            }
            guard let url = URL(string: path, relativeTo: baseURL)?.absoluteURL,
                  url.scheme?.lowercased() == "https",
                  url.host != nil else {
                throw MediaResolutionError.invalidReference(reference.rawValue)
            }
            return .remote(url)
        }
    }
}
