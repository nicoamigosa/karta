import Foundation

/// The active feed filters chosen by the user.
public struct FeedFilters: Equatable, Sendable {
    /// Allergen tags the user must never be shown. Hard safety constraint.
    public var intolerances: Set<Allergen>
    /// Upper bound on total cooking time, in minutes. `nil` means no limit.
    public var maxMinutes: Int?
    /// Hardest difficulty the user is willing to cook. `nil` means no limit.
    public var maxDifficulty: Difficulty?
    /// When true, only recipes tagged one-pan are shown.
    public var requireOnePan: Bool

    /// The tag a recipe carries to mark it as a single-pan dish.
    public static let onePanTag = "one-pan"

    public init(
        intolerances: Set<Allergen> = [],
        maxMinutes: Int? = nil,
        maxDifficulty: Difficulty? = nil,
        requireOnePan: Bool = false
    ) {
        self.intolerances = intolerances
        self.maxMinutes = maxMinutes
        self.maxDifficulty = maxDifficulty
        self.requireOnePan = requireOnePan
    }

    /// Whether a reviewed recipe satisfies every hard constraint. The
    /// intolerance check is a critical safety guarantee; unreviewed recipes
    /// are never allowed through.
    public func allows(_ recipe: Recipe) -> Bool {
        guard case let .reviewed(allergens) = recipe.allergenReview else {
            return false
        }
        return allergens.isDisjoint(with: intolerances)
            && (maxMinutes.map { recipe.totalMinutes <= $0 } ?? true)
            && (maxDifficulty.map { recipe.difficulty <= $0 } ?? true)
            && (!requireOnePan || recipe.tags.contains(Self.onePanTag))
    }
}

/// The feed recommendation as a pure function over a recipe set, dated view
/// history, an explicit recency window, and the active filters. No I/O, no ML
/// — deterministic and testable.
public enum FeedQuery {

    public static func feed(
        recipes: [Recipe],
        views: [ViewEntry],
        recentWindow: TimeInterval,
        clock: any KartaClock,
        filters: FeedFilters
    ) -> [Recipe] {
        // Apply every hard constraint, including the intolerance safety guarantee.
        let eligible = recipes.filter(filters.allows)

        let now = clock.now
        let lowerBound = now.addingTimeInterval(-recentWindow)
        let recentlyViewedIDs = Set(
            views
                .filter { $0.date >= lowerBound && $0.date <= now }
                .map(\.recipeID)
        )

        // Don't-repeat: hold back recently-viewed recipes — but never let that
        // empty the feed. Expired history naturally returns to the feed.
        let notRecentlyViewed = eligible.filter { !recentlyViewedIDs.contains($0.id) }
        let visible = notRecentlyViewed.isEmpty ? eligible : notRecentlyViewed

        // Most popular first; ties keep their original order (stable & deterministic).
        return visible
            .enumerated()
            .sorted { lhs, rhs in
                lhs.element.popularity != rhs.element.popularity
                    ? lhs.element.popularity > rhs.element.popularity
                    : lhs.offset < rhs.offset
            }
            .map(\.element)
    }
}
