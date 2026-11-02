import Foundation
import KartaCore

/// End-of-deck data. The shell rebounds the Card and shows the hint for 3 seconds.
public struct LastCardPresentation: Equatable, Sendable {
    public let hint: String
    public let hintDuration: TimeInterval = 3
    public let showsCardsBehind = false
}

extension KartaState {
    public func lastCard(recipeID: String, world: World, recipes: [Recipe], clock: any KartaClock) -> LastCardPresentation? {
        let deck = world == .leftovers ? leftoversFeed(recipes: recipes, clock: clock)
            : feed(recipes: recipes, clock: clock)
        guard deck?.recipes.last?.id == recipeID else { return nil }
        return LastCardPresentation(hint: world == .leftovers ? "That's all your leftovers" : "You've seen every recipe")
    }
}

/// Signed Leftovers copy shared by Card, reverse, empty states and toast.
public enum LeftoversCopy {
    public static let seeButtonTitle = "See"
    public static func joined(_ names: [String]) -> String {
        guard names.count > 1 else { return names.first ?? "" }
        return names.dropLast().joined(separator: ", ") + " and " + names.last!
    }

    public static func pill(_ reuse: [PurchasePolicy.ReusedIngredient]) -> String? {
        guard let first = reuse.first else { return nil }
        return first.ingredient.shortName + (reuse.count > 1 ? " + \(reuse.count - 1)" : "")
    }

    public static func note(_ reuse: [PurchasePolicy.ReusedIngredient]) -> String? {
        guard !reuse.isEmpty else { return nil }
        var ids = Set<String>()
        let sources = reuse.flatMap(\.sources).sorted { $0.date > $1.date }
            .filter { ids.insert($0.recipeID).inserted }
        let origin = sources.count >= 3 ? "what you cooked this week"
            : "your " + joined(sources.map(\.recipeName))
        return "Uses the \(joined(reuse.map { $0.ingredient.shortName })) left from \(origin)"
    }
}

extension KartaState {
    public func cardPresentation(for recipe: Recipe, world: World, recipes: [Recipe], clock: any KartaClock) -> RecipeCardPresentation? {
        guard effectiveFeedFilters.allows(recipe) else { return nil }
        if world == .leftovers {
            guard leftoversFeed(recipes: recipes, clock: clock).recipes.contains(where: { $0.id == recipe.id }) else { return nil }
        }
        let reuse = world == .leftovers ? PurchasePolicy.reusedIngredients(
            in: recipe, recipes: recipes, cooks: cookHistory, now: clock.now,
            intolerances: safetyProfile.intolerances) : []
        return RecipeCardPresentation(recipe: recipe, householdSize: onboarding.householdSize ?? recipe.servings,
                                      intolerances: safetyProfile.intolerances, leftoversPill: LeftoversCopy.pill(reuse))
    }

    /// The caller captures the origin when opening, so Cookbook reverses never gain a note.
    public func reversePresentation(for recipe: Recipe, openedFrom world: World?, recipes: [Recipe], clock: any KartaClock) -> RecipeReversePresentation? {
        guard canOpenRecipe(recipe) else { return nil }
        let reuse = world == .leftovers ? PurchasePolicy.reusedIngredients(
            in: recipe, recipes: recipes, cooks: cookHistory, now: clock.now,
            intolerances: safetyProfile.intolerances) : []
        return RecipeReversePresentation(recipe: recipe, intolerances: safetyProfile.intolerances,
            isSaved: cookbook.isSaved(recipe.id), isOnList: shoppingList.contains(recipe.id),
            leftoversNote: LeftoversCopy.note(reuse))
    }
}

extension KartaStore {
    public func leftoversFeed(recipes: [Recipe], clock: any KartaClock) -> Feed {
        state.leftoversFeed(recipes: recipes, clock: clock)
    }

    public func lastCard(recipeID: String, world: World, recipes: [Recipe], clock: any KartaClock) -> LastCardPresentation? {
        state.lastCard(recipeID: recipeID, world: world, recipes: recipes, clock: clock)
    }

    public func cardPresentation(for recipe: Recipe, world: World, recipes: [Recipe], clock: any KartaClock) -> RecipeCardPresentation? {
        state.cardPresentation(for: recipe, world: world, recipes: recipes, clock: clock)
    }

    public func reversePresentation(for recipe: Recipe, openedFrom world: World?, recipes: [Recipe], clock: any KartaClock) -> RecipeReversePresentation? {
        state.reversePresentation(for: recipe, openedFrom: world, recipes: recipes, clock: clock)
    }
}

public enum LeftoversEmptyState: Equatable, Sendable {
    case none
    case noMatchForProfile(allergens: String)
    case nothingCooked
    case nothingToReuse(line: String)
    case noMatchForFilters(summary: String, keptIntolerances: String?)

    public var title: String? {
        switch self {
        case .none: nil
        case .noMatchForProfile: "No recipes fit your intolerances yet"
        case .nothingCooked: "Nothing cooked yet"
        case .nothingToReuse: "Nothing to reuse right now"
        case .noMatchForFilters: "Nothing fits these filters"
        }
    }
    public var line: String? {
        switch self {
        case .none: nil
        case let .noMatchForProfile(allergens):
            "None of our recipes is free of \(allergens). That gap is ours to fill, not yours."
        case .nothingCooked:
            "Cook a recipe and tell us how it turned out. Recipes that use what's left over show up here."
        case let .nothingToReuse(line): line
        case let .noMatchForFilters(summary, _): summary
        }
    }
    public var primaryButtonTitle: String? {
        switch self {
        case .none: nil
        case .noMatchForFilters: "Change filters"
        default: "Go to For You"
        }
    }
    public var secondaryButtonTitle: String? {
        if case .noMatchForFilters = self { return "Clear all filters" }
        return nil
    }
    public var secondaryAction: KartaAction? {
        if case .noMatchForFilters = self { return .filter(.reset) }
        return nil
    }
    public var intoleranceNote: String? {
        if case let .noMatchForFilters(_, kept?) = self {
            return "Clearing keeps your intolerances: \(kept)."
        }
        return nil
    }
    public var primaryAction: KartaAction? {
        switch self {
        case .none: nil
        case .noMatchForFilters: nil // The shell owns opening its filter sheet.
        default: .selectWorld(.forYou)
        }
    }
}

extension LeftoversCopy {
    static func filterLine(_ draft: FilterDraft) -> String {
        var clauses: [String] = []
        if let minutes = draft.maxMinutes {
            clauses.append("is ready in \(minutes == 60 ? "1 hour" : "\(minutes) min")")
        }
        if let difficulty = draft.maxDifficulty {
            switch difficulty {
            case .easy: clauses.append("is easy")
            case .medium: clauses.append("is medium or easier")
            case .hard: break
            }
        }
        if let diet = draft.diet { clauses.append("is \(diet.rawValue)") }
        clauses += PracticalTag.allCases.filter { draft.practicalTags.contains($0) }.map { "is \($0.rawValue)" }
        if let course = draft.course { clauses.append("fits \(course.rawValue)") }
        return "No leftover recipe " + (clauses.isEmpty ? "to show" : clauses.joined(separator: " and ")) + "."
    }
}

extension KartaState {
    public func leftoversEmptyState(recipes: [Recipe], clock: any KartaClock) -> LeftoversEmptyState {
        let safety = FeedFilters(intolerances: safetyProfile.intolerances)
        let allergens = Allergen.allCases.filter { safetyProfile.intolerances.contains($0) }.map(\.rawValue)
        guard recipes.contains(where: safety.allows) else {
            return .noMatchForProfile(allergens: LeftoversCopy.joined(allergens))
        }
        let explicit = cookHistory.enumerated().filter { !$0.element.wasInferred && $0.element.date <= clock.now }
            .sorted { $0.element.date == $1.element.date ? $0.offset > $1.offset : $0.element.date > $1.element.date }
            .map(\.element)
        guard let latest = explicit.first else { return .nothingCooked }
        let window = PurchasePolicy.leftoversWindow
        if latest.date < clock.now.addingTimeInterval(-window) {
            let name = recipes.first { $0.id == latest.recipeID }.map { " \($0.name)" } ?? ""
            let days = Int(clock.now.timeIntervalSince(latest.date) / 86400)
            return .nothingToReuse(line: "You last cooked\(name) \(days) \(days == 1 ? "day" : "days") ago. Leftovers looks back 7 days.")
        }
        let unfiltered = LeftoversQuery.suggestions(recipes: recipes, cooks: cookHistory,
            recentWindow: window, clock: clock, filters: safety)
        guard !unfiltered.isEmpty else {
            var ids = Set<String>()
            let names = explicit.filter { $0.date >= clock.now.addingTimeInterval(-window) && ids.insert($0.recipeID).inserted }
                .compactMap { cook in recipes.first { $0.id == cook.recipeID }?.name }.prefix(2)
            let origin = names.isEmpty ? "you cooked this week" : "your \(LeftoversCopy.joined(Array(names))) left over"
            return .nothingToReuse(line: "No other recipe uses what \(origin).")
        }
        guard leftoversFeed(recipes: recipes, clock: clock).isEmpty else { return .none }
        let kept = allergens.isEmpty ? nil : "\(LeftoversCopy.joined(allergens)) \(allergens.count == 1 ? "stays" : "stay") hidden"
        return .noMatchForFilters(summary: LeftoversCopy.filterLine(filterDraft), keptIntolerances: kept)
    }
}

extension KartaStore {
    public func leftoversEmptyState(recipes: [Recipe], clock: any KartaClock) -> LeftoversEmptyState {
        state.leftoversEmptyState(recipes: recipes, clock: clock)
    }
}

extension LeftoversCopy {
    static func toast(recipe: Recipe, count: Int, ingredients: [Ingredient]) -> LeftoversToast {
        LeftoversToast(recipeID: recipe.id, ideaCount: count,
            title: "\(count) \(count == 1 ? "idea" : "ideas") for your leftovers",
            line: "From the \(joined(ingredients.map(\.shortName))) of your \(recipe.name)")
    }
}
