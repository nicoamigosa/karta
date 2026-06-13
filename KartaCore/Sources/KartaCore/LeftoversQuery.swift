import Foundation

/// The Leftovers loop as a pure function. Given what the user recently cooked
/// (the `cooked` events) and the recipe set, it surfaces recipes that reuse
/// ingredients from those cooked recipes — so food is wasted less, with no
/// pantry or inventory tracking. Deterministic and UI-independent.
public enum LeftoversQuery {

    /// Recipes that reuse ingredients from recently-cooked recipes, most overlap
    /// first. Recently-cooked recipes are excluded, and the intolerance safety
    /// guarantee in `filters` is always applied.
    public static func suggestions(
        recipes: [Recipe],
        cookedRecipeIDs: Set<String>,
        filters: FeedFilters
    ) -> [Recipe] {
        // The pool of ingredients freed up by what was just cooked.
        let cookedIngredients: Set<String> = recipes
            .filter { cookedRecipeIDs.contains($0.id) }
            .reduce(into: []) { acc, recipe in
                acc.formUnion(recipe.ingredients.map { normalize($0.name) })
            }

        return recipes
            .filter { !cookedRecipeIDs.contains($0.id) }   // don't re-suggest cooked
            .filter(filters.allows)                        // safety always applies
            .compactMap { recipe -> (Recipe, Int, Int)? in
                let overlap = recipe.ingredients
                    .filter { cookedIngredients.contains(normalize($0.name)) }
                    .count
                return overlap > 0 ? (recipe, overlap, 0) : nil
            }
            .enumerated()
            .sorted { lhs, rhs in
                lhs.element.1 != rhs.element.1
                    ? lhs.element.1 > rhs.element.1   // more overlap first
                    : lhs.offset < rhs.offset         // stable tie-break
            }
            .map(\.element.0)
    }

    private static func normalize(_ name: String) -> String {
        name.lowercased()
    }
}
