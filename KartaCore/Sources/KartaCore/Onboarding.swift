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

/// Gusto is an explainable affinity score, never an eligibility rule.
/// Each distinct opened recipe contributes +3, each save +5 (additive).
/// A Vista with neither an Apertura nor a save contributes only -1.
/// Repeated openings do not amplify a signal. No clock, decay, ML or calibration.
/// Shared primary Course, Diet, Practical tags and required ingredients each
/// add affinity; the recipe itself adds 4. Unknown history IDs have no effect.
public struct TastePreferences: Equatable, Sendable {
    private let scores: [String: Int]

    public init(recipes: [Recipe] = [], history: ViewHistory = ViewHistory(), savedIDs: [String] = []) {
        let opened = Set(history.openings.map(\.recipeID))
        let saved = Set(savedIDs)
        let viewed = Set(history.entries.map(\.recipeID))
        let signals = recipes.compactMap { recipe -> (Recipe, Int)? in
            let weight = (opened.contains(recipe.id) ? 3 : 0)
                + (saved.contains(recipe.id) ? 5 : 0)
                - (viewed.contains(recipe.id) && !opened.contains(recipe.id)
                    && !saved.contains(recipe.id) ? 1 : 0)
            return weight == 0 ? nil : (recipe, weight)
        }
        var scores: [String: Int] = [:]
        for candidate in recipes {
            scores[candidate.id] = signals.reduce(0) { sum, signal in
                let (source, weight) = signal
                let affinity = (candidate.id == source.id ? 4 : 0)
                    + (candidate.primaryCourse == source.primaryCourse ? 1 : 0)
                    + candidate.diets.intersection(source.diets).count
                    + candidate.practicalTags.intersection(source.practicalTags).count
                    + Self.ingredients(candidate).intersection(Self.ingredients(source)).count
                return sum + weight * affinity
            }
        }
        self.scores = scores
    }

    public func score(for recipe: Recipe) -> Int { scores[recipe.id, default: 0] }

    private static func ingredients(_ recipe: Recipe) -> Set<String> {
        Set(recipe.ingredients.filter { !$0.isOptional }.map {
            $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        })
    }
}
