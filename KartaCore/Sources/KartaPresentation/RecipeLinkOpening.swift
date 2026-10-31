import KartaCore

/// The shell renders the returned reverse; navigation and Apertura are already recorded.
public enum RecipeLinkOpening: Equatable, Sendable {
    case reverse(RecipeReversePresentation)
    case gone
    /// No receiver UI is decided for unsafe or otherwise unavailable recipes.
    case notOffered
    case ignored
}

/// One-shot Feed notice; its lifetime and animation belong to the shell.
public struct RecipeGoneNotice: Equatable, Sendable {
    public let title = "This recipe is no longer on Karta"
    public let message = "Here's your deck instead."

    public init() {}
}
