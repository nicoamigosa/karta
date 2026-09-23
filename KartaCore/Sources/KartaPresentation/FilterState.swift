import KartaCore

/// The safety constraints declared by the user.
public struct SafetyProfile: Equatable, Sendable {
    /// Allergens the user must never be shown.
    public let intolerances: Set<Allergen>

    /// Build a profile from the user's explicit intolerance choices.
    public init(intolerances: Set<Allergen>) {
        self.intolerances = intolerances
    }
}

/// The non-safety controls currently applied to the feed.
public struct FilterDraft: Equatable, Sendable {
    /// Upper bound on total cooking time, in minutes. `nil` means no limit.
    public var maxMinutes: Int?
    /// Hardest difficulty the user is willing to cook. `nil` means no limit.
    public var maxDifficulty: Difficulty?
    /// When true, only recipes tagged one-pan are shown.
    public var requireOnePan: Bool

    public init(
        maxMinutes: Int? = nil,
        maxDifficulty: Difficulty? = nil,
        requireOnePan: Bool = false
    ) {
        self.maxMinutes = maxMinutes
        self.maxDifficulty = maxDifficulty
        self.requireOnePan = requireOnePan
    }
}

/// Actions that can change feed filter state.
public enum FilterAction: Sendable {
    /// Commit the time, difficulty and one-pan controls from the filter sheet.
    case apply(FilterDraft)
    /// Discard an uncommitted filter-sheet edit. The view owns that edit.
    case cancel
    /// Clear the non-safety controls.
    case reset
    /// Update the safety profile independently of the non-safety controls.
    /// This action has no subscription input: safety editing is always free.
    case setSafetyProfile(SafetyProfile)
}

/// Presentation state for the feed's safety profile and filter draft.
public struct FilterState: Equatable, Sendable {
    public private(set) var safetyProfile: SafetyProfile
    public private(set) var filterDraft: FilterDraft

    public init(
        safetyProfile: SafetyProfile,
        filterDraft: FilterDraft = FilterDraft()
    ) {
        self.safetyProfile = safetyProfile
        self.filterDraft = filterDraft
    }

    /// The only composition point for the safety profile and filter draft.
    public var effectiveFeedFilters: FeedFilters {
        FeedFilters(
            intolerances: safetyProfile.intolerances,
            maxMinutes: filterDraft.maxMinutes,
            maxDifficulty: filterDraft.maxDifficulty,
            requireOnePan: filterDraft.requireOnePan
        )
    }

    public mutating func reduce(_ action: FilterAction) {
        switch action {
        case let .apply(filterDraft):
            self.filterDraft = filterDraft
        case .cancel:
            break
        case .reset:
            filterDraft = FilterDraft()
        case let .setSafetyProfile(safetyProfile):
            self.safetyProfile = safetyProfile
        }
    }
}
