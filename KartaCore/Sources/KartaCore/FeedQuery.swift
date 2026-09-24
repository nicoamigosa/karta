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
            && (!requireOnePan || recipe.tags.contains(.onePan))
    }
}

/// The ordered stretches of a feed, including the point where new recipes
/// end and already-seen recipes begin.
public struct Feed: Equatable, Sendable {

    /// Whether the active filters have anything new to offer, or anything at
    /// all that is compatible with the user's profile.
    public enum Status: Equatable, Sendable {
        case ready
        case exhausted
        case noCompatibleRecipes
    }

    /// One renderable unit in feed order. The frontier is data, not a recipe,
    /// so the UI can label it without inferring a boundary from array indexes.
    public enum Item: Equatable, Sendable {
        case new(Recipe)
        case frontier
        case alreadySeen(Recipe)
    }

    /// Recipes outside the active recency window, in ranking order.
    public let newRecipes: [Recipe]
    /// Recipes inside the active recency window, in ranking order.
    public let alreadySeenRecipes: [Recipe]

    public init(newRecipes: [Recipe], alreadySeenRecipes: [Recipe]) {
        self.newRecipes = newRecipes
        self.alreadySeenRecipes = alreadySeenRecipes
    }

    public var status: Status {
        if newRecipes.isEmpty && alreadySeenRecipes.isEmpty {
            .noCompatibleRecipes
        } else if newRecipes.isEmpty {
            .exhausted
        } else {
            .ready
        }
    }

    /// The complete feed, with the frontier between its two recipe stretches.
    /// A compatible catalog always contributes at least one recipe, even when
    /// every compatible recipe is already inside the recency window.
    public var items: [Item] {
        guard status != .noCompatibleRecipes else { return [] }
        return newRecipes.map(Item.new)
            + [.frontier]
            + alreadySeenRecipes.map(Item.alreadySeen)
    }

    /// The recipes in feed order, excluding the non-recipe frontier item.
    public var recipes: [Recipe] {
        newRecipes + alreadySeenRecipes
    }

    /// True only when the active profile has no compatible recipe.
    public var isEmpty: Bool {
        status == .noCompatibleRecipes
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
        filters: FeedFilters,
        tastePreferences: TastePreferences = TastePreferences(),
        householdSize: Int? = nil
    ) -> Feed {
        if let householdSize {
            precondition(householdSize > 0, "householdSize must be positive")
        }

        // Apply every hard constraint, including the intolerance safety guarantee.
        let eligible = recipes.filter(filters.allows)

        let now = clock.now
        let lowerBound = now.addingTimeInterval(-recentWindow)
        let recentlyViewedIDs = Set(
            views
                .filter { $0.date >= lowerBound && $0.date <= now }
                .map(\.recipeID)
        )

        // Don't-repeat: put recently-viewed recipes below the frontier. Expired
        // history naturally returns to the new stretch without restarting the
        // feed or mutating the view history.
        let newRecipes = eligible.filter { !recentlyViewedIDs.contains($0.id) }
        let alreadySeenRecipes = eligible.filter { recentlyViewedIDs.contains($0.id) }

        // Taste and household fit lead the ranking; popularity breaks ties.
        return Feed(
            newRecipes: ranked(
                newRecipes,
                tastePreferences: tastePreferences,
                householdSize: householdSize
            ),
            alreadySeenRecipes: ranked(
                alreadySeenRecipes,
                tastePreferences: tastePreferences,
                householdSize: householdSize
            )
        )
    }

    private static func ranked(
        _ recipes: [Recipe],
        tastePreferences: TastePreferences,
        householdSize: Int?
    ) -> [Recipe] {
        recipes
            .enumerated()
            .sorted { lhs, rhs in
                let lhsTaste = tastePreferences.favors(lhs.element)
                let rhsTaste = tastePreferences.favors(rhs.element)
                if lhsTaste != rhsTaste { return lhsTaste }

                if let householdSize {
                    let lhsDistance = abs(lhs.element.servings - householdSize)
                    let rhsDistance = abs(rhs.element.servings - householdSize)
                    if lhsDistance != rhsDistance { return lhsDistance < rhsDistance }
                }

                return lhs.element.popularity != rhs.element.popularity
                    ? lhs.element.popularity > rhs.element.popularity
                    : lhs.offset < rhs.offset
            }
            .map(\.element)
    }
}
