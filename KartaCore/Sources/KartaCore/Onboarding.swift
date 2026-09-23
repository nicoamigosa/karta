import Foundation

/// What minimal onboarding collects: the safety-critical intolerances (required)
/// and household size (one question). Taste, skill, cuisines and units/language
/// are learned from behavior / inferred from the device locale — not asked here.
public struct OnboardingProfile: Equatable, Sendable {
    /// Allergens/intolerances the user must never be shown. Safety-critical.
    public let intolerances: Set<Allergen>
    /// Number of people the user typically cooks for.
    public let householdSize: Int

    public init(intolerances: Set<Allergen>, householdSize: Int) {
        precondition(householdSize > 0, "householdSize must be positive")
        self.intolerances = intolerances
        self.householdSize = householdSize
    }

    /// Feeds the collected intolerances into the pure feed engine, so the very
    /// first feed is already safe and non-generic.
    public var feedFilters: FeedFilters {
        FeedFilters(intolerances: intolerances)
    }
}

/// The taste-calibration mini-flow: the user taps recipes that appeal during a
/// real vertical-scroll experience. Its taps seed taste preferences and are a
/// **separate channel** from the cookbook — they never consume the free save
/// cap (a calibration tap is not a save).
public struct TasteCalibration: Equatable, Sendable {
    public private(set) var likedIDs: [String]

    public init(likedIDs: [String] = []) {
        self.likedIDs = likedIDs
    }

    /// Record an appealing recipe. Idempotent; preserves tap order.
    public mutating func tap(_ id: String) {
        guard !likedIDs.contains(id) else { return }
        likedIDs.append(id)
    }
}
