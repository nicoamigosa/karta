import Foundation

/// What gets handed to the native share sheet: a human-readable line plus a
/// stable reference URL that identifies the recipe. UI-independent and testable.
public struct SharePayload: Equatable, Sendable {
    public let text: String
    public let url: URL?

    public init(text: String, url: URL?) {
        self.text = text
        self.url = url
    }
}

/// Assembles the share payload for a recipe. The presentation of the iOS share
/// sheet itself lives in the UI shell; this is just the payload.
public struct RecipeShare: Sendable {

    public let baseURL: URL?

    public init(baseURL: URL? = nil) {
        self.baseURL = baseURL
    }

    public func payload(for recipe: Recipe) -> SharePayload {
        SharePayload(
            text: "Check out \(recipe.name) on Karta",
            url: referenceURL(for: recipe.id)
        )
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
