import Foundation

/// The outcome of attempting to save a recipe.
public enum SaveResult: Equatable, Sendable {
    case saved
    case alreadySaved
    /// The free-tier cap was reached: the moment to surface the upgrade invitation.
    case blockedByCap
}

/// The user's personal cookbook of saved recipes, with the free-tier save cap.
/// Pure value type — persistence and the save animation live in the UI shell.
public struct Cookbook: Equatable, Sendable {
    /// Free-tier users can save at most this many recipes.
    public static let freeSaveCap = 7

    public private(set) var savedIDs: [String]
    /// `nil` means unlimited (e.g. premium). Defaults to the free-tier cap.
    public let saveCap: Int?

    public init(savedIDs: [String] = [], saveCap: Int? = Cookbook.freeSaveCap) {
        self.savedIDs = savedIDs
        self.saveCap = saveCap
    }

    public func isSaved(_ id: String) -> Bool {
        savedIDs.contains(id)
    }

    /// Whether the cookbook is at its cap (the upgrade-invitation moment).
    public var isAtCap: Bool {
        saveCap.map { savedIDs.count >= $0 } ?? false
    }

    /// Save a recipe. Idempotent; blocked once the cap is reached.
    @discardableResult
    public mutating func save(_ id: String) -> SaveResult {
        if isSaved(id) { return .alreadySaved }
        if isAtCap { return .blockedByCap }
        savedIDs.append(id)
        return .saved
    }

    /// Remove a recipe, freeing a slot.
    public mutating func unsave(_ id: String) {
        savedIDs.removeAll { $0 == id }
    }
}
