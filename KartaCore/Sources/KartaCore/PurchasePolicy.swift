import Foundation

/// Shared defaults for Leftovers and shopping; keys are products, never name matching.
public enum PurchasePolicy {
    public static let leftoversWindow: TimeInterval = 7 * 24 * 60 * 60
    public static let pantryBasics: Set<String> = [
        "salt", "kosher-salt", "sea-salt", "table-salt", "pepper", "black-pepper",
        "ground-black-pepper", "olive-oil", "extra-virgin-olive-oil", "vegetable-oil",
        "canola-oil", "sunflower-oil", "coconut-oil", "sesame-oil", "peanut-oil",
        "avocado-oil", "flour", "all-purpose-flour", "bread-flour", "whole-wheat-flour",
        "sugar", "granulated-sugar", "brown-sugar", "powdered-sugar",
        "yeast", "active-dry-yeast", "instant-yeast",
    ]

    public struct Source: Equatable, Sendable {
        public let recipeID: String
        public let recipeName: String
        public let date: Date
    }

    public struct ReusedIngredient: Equatable, Sendable {
        public let ingredient: Ingredient
        /// Distinct source recipes, most recent first.
        public let sources: [Source]
    }

    /// The common answer for the shopping add sheet and Leftovers explanations.
    public static func reusedIngredients(
        in recipe: Recipe, recipes: [Recipe], cooks: [CookEntry], now: Date,
        window: TimeInterval = leftoversWindow, intolerances: Set<Allergen> = []
    ) -> [ReusedIngredient] {
        let sources = leftoverSources(recipes: recipes, cooks: cooks, now: now,
                                      window: window, intolerances: intolerances)
        var keys = Set<String>()
        return recipe.visibleIngredients(for: intolerances).compactMap { ingredient in
            guard !ingredient.isOptional, ingredient.allergens.isDisjoint(with: intolerances),
                  let matches = sources[ingredient.purchaseKey],
                  keys.insert(ingredient.purchaseKey).inserted else { return nil }
            return ReusedIngredient(ingredient: ingredient, sources: matches)
        }
    }

    /// Compatibility projection: most recent explicit cook supplies the name.
    public static func leftovers(
        recipes: [Recipe], cooks: [CookEntry], now: Date,
        window: TimeInterval = leftoversWindow, intolerances: Set<Allergen> = []
    ) -> [String: String] {
        leftoverSources(recipes: recipes, cooks: cooks, now: now,
                        window: window, intolerances: intolerances).compactMapValues { $0.first?.recipeName }
    }

    private static func leftoverSources(
        recipes: [Recipe], cooks: [CookEntry], now: Date,
        window: TimeInterval, intolerances: Set<Allergen>
    ) -> [String: [Source]] {
        var result: [String: [Source]] = [:]
        for cook in cooks.enumerated().sorted(by: {
            $0.element.date == $1.element.date ? $0.offset > $1.offset : $0.element.date > $1.element.date
        }).map(\.element) where !cook.wasInferred && cook.date <= now && cook.date >= now.addingTimeInterval(-window) {
            guard let recipe = recipes.first(where: { $0.id == cook.recipeID }) else { continue }
            for ingredient in recipe.visibleIngredients(for: intolerances)
                where !ingredient.isOptional && ingredient.allergens.isDisjoint(with: intolerances)
                    && !pantryBasics.contains(ingredient.purchaseKey) {
                if !(result[ingredient.purchaseKey] ?? []).contains(where: { $0.recipeID == recipe.id }) {
                    result[ingredient.purchaseKey, default: []].append(
                        Source(recipeID: recipe.id, recipeName: recipe.name, date: cook.date))
                }
            }
        }
        return result
    }
}
