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
public enum RecipeShare {

    /// Base for the stable per-recipe reference link.
    public static let referenceBase = "https://karta.app/r/"

    public static func payload(for recipe: Recipe) -> SharePayload {
        SharePayload(
            text: "Check out \(recipe.name) on Karta",
            url: URL(string: referenceBase + recipe.id)
        )
    }
}
