import KartaCore

/// Why For You has no recipes to offer. Crossing the Frontera is not empty.
public enum FeedEmptyState: Equatable, Sendable {
    case none
    case noMatchForProfile(allergens: String)
    case noMatchForFilters(summary: String, keptIntolerances: String?)

    init(feed: Feed, recipes: [Recipe], draft: FilterDraft, safetyProfile: SafetyProfile) {
        guard feed.recipes.isEmpty else {
            self = .none
            return
        }
        let allergens = Allergen.allCases.filter { safetyProfile.intolerances.contains($0) }.map(\.rawValue)
        let allergenList: String
        if allergens.count > 1 {
            allergenList = allergens.dropLast().joined(separator: ", ") + " and " + allergens.last!
        } else {
            allergenList = allergens.first ?? ""
        }
        let safety = FeedFilters(intolerances: safetyProfile.intolerances)
        guard recipes.contains(where: safety.allows) else {
            self = .noMatchForProfile(allergens: allergenList)
            return
        }
        var adjectives: [String] = []
        if draft.maxDifficulty == .easy { adjectives.append("easy") }
        if let diet = draft.diet { adjectives.append(diet.rawValue) }
        adjectives += PracticalTag.allCases.filter { draft.practicalTags.contains($0) }.map(\.rawValue)
        let subject = (["No"] + adjectives + ["recipe"]).joined(separator: " ")
        var clauses: [String] = []
        if let minutes = draft.maxMinutes {
            clauses.append("is ready in \(minutes == 60 ? "1 hour" : "\(minutes) min")")
        }
        if draft.maxDifficulty == .medium { clauses.append("is medium or easier") }
        let clause = clauses.isEmpty ? "to show" : clauses.joined(separator: " and ")
        self = .noMatchForFilters(summary: "\(subject) \(clause).",
                                  keptIntolerances: allergens.isEmpty ? nil
                                    : "\(allergenList) \(allergens.count == 1 ? "stays" : "stay") hidden")
    }
}
