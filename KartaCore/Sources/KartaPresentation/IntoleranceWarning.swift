import KartaCore

/// Stable warning order follows the closed allergen vocabulary.
enum IntoleranceWarning {
    static func note(recipe: Recipe, intolerances: Set<Allergen>) -> String? {
        guard case let .reviewed(allergens) = recipe.allergenReview else { return nil }
        let names = Allergen.allCases.filter { allergens.contains($0) && intolerances.contains($0) }
            .map(\.rawValue)
        guard !names.isEmpty else { return nil }
        let qualifier = names.count == 1 ? "one of" : "among"
        return "Contains \(names.joined(separator: ", ")), \(qualifier) your intolerances"
    }

    static func tag(for allergens: Set<Allergen>) -> String? {
        guard let first = Allergen.allCases.first(where: allergens.contains) else { return nil }
        let name = first.rawValue.capitalized
        return allergens.count > 1 ? "\(name) +\(allergens.count - 1)" : name
    }
}
