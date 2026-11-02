/// User-owned memory of the See toast, independent of the cooking session.
public struct LeftoversToastHistory: Equatable, Sendable {
    public private(set) var shownRecipeIDs: Set<String>
    public private(set) var consecutiveDismissals: Int

    public enum Close: Sendable { case see, dismissed }

    public init(shownRecipeIDs: Set<String> = [], consecutiveDismissals: Int = 0) {
        precondition(consecutiveDismissals >= 0)
        self.shownRecipeIDs = shownRecipeIDs
        self.consecutiveDismissals = consecutiveDismissals
    }

    public mutating func offer(recipeID: String) -> Bool {
        guard consecutiveDismissals < 3 else { return false }
        return shownRecipeIDs.insert(recipeID).inserted
    }

    public mutating func close(as action: Close) {
        switch action {
        case .see: consecutiveDismissals = 0
        case .dismissed: consecutiveDismissals += 1
        }
    }
}
