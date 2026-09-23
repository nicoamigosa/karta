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
    /// `nil` means unlimited (e.g. premium). A finite value is the persisted
    /// ceiling for the free tier.
    public private(set) var saveCap: Int?

    public init(savedIDs: [String] = [], saveCap: Int? = Cookbook.freeSaveCap) {
        precondition(saveCap.map { $0 >= 0 } ?? true, "saveCap must not be negative")

        var uniqueIDs: [String] = []
        uniqueIDs.reserveCapacity(savedIDs.count)
        for id in savedIDs where !uniqueIDs.contains(id) {
            uniqueIDs.append(id)
        }
        self.savedIDs = uniqueIDs
        self.saveCap = saveCap
    }

    public func isSaved(_ id: String) -> Bool {
        savedIDs.contains(id)
    }

    /// Resolve persisted recipe IDs against the current catalog in saved order.
    /// Missing or unsafe recipes are omitted so restored Cookbook entries
    /// cannot bypass the catalog's safety boundary. Filtering never mutates
    /// the saved IDs.
    public func recipes(
        from catalog: [Recipe],
        filters: FeedFilters = FeedFilters()
    ) -> [Recipe] {
        let recipesByID = Dictionary(
            catalog.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        return savedIDs.compactMap { id in
            guard let recipe = recipesByID[id] else { return nil }
            guard filters.allows(recipe) else { return nil }
            return recipe
        }
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

    /// Move an unlimited Cookbook to the free tier without deleting saves.
    /// The ceiling is fixed at the accumulated count, or the normal free cap
    /// when fewer than seven recipes were saved.
    public mutating func downgradeToFree() {
        guard saveCap == nil else { return }
        saveCap = max(Self.freeSaveCap, savedIDs.count)
    }

    /// Remove a recipe. A finite ceiling follows the saved count down to the
    /// normal free cap, so this does not free a slot above that floor.
    public mutating func unsave(_ id: String) {
        guard isSaved(id) else { return }
        savedIDs.removeAll { $0 == id }
        if let saveCap {
            self.saveCap = max(Self.freeSaveCap, min(saveCap, savedIDs.count))
        }
    }
}
