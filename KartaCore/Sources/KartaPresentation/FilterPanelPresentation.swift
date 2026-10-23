import KartaCore

/// The filter panel's ordered controls, projected from the shell's local draft
/// and the store's current safety profile. Intolerancias are never draft edits.
public struct FilterPanelPresentation: Equatable, Sendable {
    public struct Option<Value: Equatable & Sendable>: Equatable, Sendable {
        public let value: Value
        public let label: String
        public let isOn: Bool
    }

    public struct Intolerance: Equatable, Sendable {
        public let allergen: Allergen
        public let label: String
        public let isOn: Bool
    }

    private let draft: FilterDraft
    private let safetyProfile: SafetyProfile

    public init(draft: FilterDraft, safetyProfile: SafetyProfile) {
        self.draft = draft
        self.safetyProfile = safetyProfile
    }

    public var intolerances: [Intolerance] {
        Allergen.allCases.map {
            Intolerance(allergen: $0, label: Self.label(for: $0),
                        isOn: safetyProfile.intolerances.contains($0))
        }
    }

    public var readyIn: [Option<Int?>] {
        [nil, 20, 30, 45, 60].map {
            Option(value: $0, label: $0.map { String($0) } ?? "Any", isOn: draft.maxMinutes == $0)
        }
    }

    public var difficulty: [Option<Difficulty?>] {
        [(nil, "Any"), (Difficulty.easy, "Easy"), (.medium, "Up to medium")].map {
            Option(value: $0.0, label: $0.1, isOn: draft.maxDifficulty == $0.0)
        }
    }

    public var practical: [Option<PracticalTag>] {
        [(PracticalTag.onePan, "One pan"), (.oven, "Oven"),
         (.makeAhead, "Make ahead"), (.shareable, "Shareable")].map {
            Option(value: $0.0, label: $0.1, isOn: draft.practicalTags.contains($0.0))
        }
    }

    public var diet: [Option<Diet?>] {
        [(nil, "Any"), (Diet.vegetarian, "Vegetarian"), (.vegan, "Vegan")].map {
            Option(value: $0.0, label: $0.1, isOn: draft.diet == $0.0)
        }
    }

    /// Only non-safety options can produce a draft edit. Course is preserved
    /// by every panel edit, including Reset, because it is not on the panel.
    public enum DraftAction: Sendable {
        case readyIn(Int?)
        case difficulty(Difficulty?)
        case practical(PracticalTag)
        case diet(Diet?)
        case reset
    }

    public func nextDraft(after action: DraftAction) -> FilterDraft {
        var next = draft
        switch action {
        case let .readyIn(minutes): next.maxMinutes = minutes
        case let .difficulty(difficulty): next.maxDifficulty = difficulty
        case let .practical(tag):
            if next.practicalTags.contains(tag) {
                next.practicalTags.remove(tag)
            } else {
                next.practicalTags.insert(tag)
            }
        case let .diet(diet): next.diet = diet
        case .reset: next = FilterDraft(course: draft.course)
        }
        return next
    }

    /// Send this result immediately with `.filter(.setSafetyProfile(_))`.
    /// It never changes the panel's draft.
    public func nextSafetyProfile(toggling allergen: Allergen) -> SafetyProfile {
        var intolerances = safetyProfile.intolerances
        if intolerances.contains(allergen) {
            intolerances.remove(allergen)
        } else {
            intolerances.insert(allergen)
        }
        return SafetyProfile(intolerances: intolerances)
    }

    /// Pass the last tapped allergen after saving its new profile, or `nil`
    /// before any change. Rebuild this projection with the current profile.
    public func intoleranceNote(after allergen: Allergen?) -> String? {
        guard let allergen else { return nil }
        let label = Self.label(for: allergen)
        if safetyProfile.intolerances.contains(allergen) {
            return "Saved. \(label) is now hidden everywhere. Reset and Clear never touch it."
        }
        return "Saved. \(label) recipes can show up again."
    }

    public static func showRecipesLabel(count: Int) -> String {
        "Show \(count) \(count == 1 ? "recipe" : "recipes")"
    }

    private static func label(for allergen: Allergen) -> String {
        switch allergen {
        case .dairy: "Dairy"
        case .egg: "Egg"
        case .fish: "Fish"
        case .gluten: "Gluten"
        case .nuts: "Nuts"
        }
    }
}
