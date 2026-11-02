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

    /// Most recent explicit cook wins the explanatory name. Future cooks never count.
    public static func leftovers(
        recipes: [Recipe], cooks: [CookEntry], now: Date,
        window: TimeInterval = leftoversWindow, intolerances: Set<Allergen> = []
    ) -> [String: String] {
        var result: [String: String] = [:]
        for cook in cooks.enumerated().sorted(by: {
            $0.element.date == $1.element.date ? $0.offset > $1.offset : $0.element.date > $1.element.date
        }).map(\.element) where !cook.wasInferred && cook.date <= now && cook.date >= now.addingTimeInterval(-window) {
            guard let recipe = recipes.first(where: { $0.id == cook.recipeID }) else { continue }
            for ingredient in recipe.visibleIngredients(for: intolerances)
                where !ingredient.isOptional && ingredient.allergens.isDisjoint(with: intolerances)
                    && !pantryBasics.contains(ingredient.purchaseKey) {
                if result[ingredient.purchaseKey] == nil { result[ingredient.purchaseKey] = recipe.name }
            }
        }
        return result
    }
}
