/// User-owned memory of finish-card sharing prompts, independent of cooking sessions.
public struct ShareCardHistory: Equatable, Sendable {
    // Provisional product defaults: keep the trigger and retirement threshold here.
    private static let trigger: CookOutcome = .thumbsUp
    private static let dismissalLimit = 3

    public private(set) var shownRecipeIDs: Set<String>
    public private(set) var consecutiveDismissals: Int

    public enum Close: Sendable {
        case shared
        case dismissed
    }

    public init(shownRecipeIDs: Set<String> = [], consecutiveDismissals: Int = 0) {
        precondition(consecutiveDismissals >= 0)
        self.shownRecipeIDs = shownRecipeIDs
        self.consecutiveDismissals = consecutiveDismissals
    }

    public func offersCard(for event: CookedEvent?) -> Bool {
        guard let event else { return false }
        return !event.wasInferred && event.outcome == Self.trigger
            && consecutiveDismissals < Self.dismissalLimit
            && !shownRecipeIDs.contains(event.recipeID)
    }

    public mutating func close(for recipeID: String, as action: Close) {
        guard consecutiveDismissals < Self.dismissalLimit,
              shownRecipeIDs.insert(recipeID).inserted else { return }
        switch action {
        case .shared: consecutiveDismissals = 0
        case .dismissed: consecutiveDismissals += 1
        }
    }
}
