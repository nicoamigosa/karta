/// The one-time free-plan invitation. The shell supplies duration and routes
/// See plans to the paywall, dismissing the toast when it expires or is tapped.
public struct SaveToast: Equatable, Sendable {
    public var title: String { "Saved to your cookbook" }
    public var secondLine: String { "1 spot left on the free plan" }
    public var action: Action { .seePlans }
    public let recipeID: String

    public enum Action: Equatable, Sendable {
        case seePlans
        public var title: String { "See plans" }
    }

    init(recipeID: String) {
        self.recipeID = recipeID
    }
}
