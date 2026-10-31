import Foundation

/// What gets handed to the native share sheet: a human-readable line plus a
/// stable reference URL that identifies the recipe. UI-independent and testable.
public struct SharePayload: Equatable, Sendable {
    public let text: String
    public let url: URL
    public let title: String
    public let subtitle: String
    public let photo: MediaReference

    public init(text: String, url: URL, title: String, subtitle: String, photo: MediaReference) {
        self.text = text
        self.url = url
        self.title = title
        self.subtitle = subtitle
        self.photo = photo
    }
}

/// Assembles the share payload for a recipe. The presentation of the iOS share
/// sheet itself lives in the UI shell; this is just the payload.
public struct RecipeShare: Sendable {

    public let baseURL: URL?

    public init(baseURL: URL? = nil) {
        self.baseURL = baseURL
    }

    public func payload(for recipe: Recipe) -> SharePayload? {
        guard let url = referenceURL(for: recipe.id) else { return nil }
        return SharePayload(
            text: "\(recipe.name) on Karta",
            url: url,
            title: recipe.name,
            subtitle: "Serves \(recipe.servings) · \(recipe.totalMinutes) min · \(recipe.difficulty.rawValue.capitalized)",
            photo: recipe.heroPhoto
        )
    }

    /// Recognizes one recipe-id segment under the injected base, without accepting
    /// other origins or paths that merely start with the same letters.
    public func recipeID(for url: URL) -> String? {
        guard let baseURL,
              let base = URLComponents(url: baseURL, resolvingAgainstBaseURL: false),
              let link = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let host = base.host,
              link.scheme?.lowercased() == base.scheme?.lowercased(),
              link.host?.lowercased() == host.lowercased(), link.port == base.port,
              link.user == nil, link.password == nil,
              link.query == nil, link.fragment == nil else { return nil }
        let prefix = base.percentEncodedPath.hasSuffix("/")
            ? base.percentEncodedPath : base.percentEncodedPath + "/"
        guard link.percentEncodedPath.hasPrefix(prefix) else { return nil }
        let segment = String(link.percentEncodedPath.dropFirst(prefix.count))
        guard !segment.isEmpty, !segment.contains("/"),
              let id = segment.removingPercentEncoding, id != ".", id != ".." else { return nil }
        return id
    }

    private func referenceURL(for recipeID: String) -> URL? {
        guard let baseURL,
              var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        else { return nil }

        let allowedCharacters = CharacterSet(
            charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~"
        )
        let encodedID = recipeID.addingPercentEncoding(withAllowedCharacters: allowedCharacters) ?? ""
        let basePath = components.percentEncodedPath
        let separator = basePath.hasSuffix("/") ? "" : "/"
        components.percentEncodedPath = basePath + separator + encodedID
        return components.url
    }
}
