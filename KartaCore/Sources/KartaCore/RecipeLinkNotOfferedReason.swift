/// Why a shared recipe cannot be proposed to its receiver. Deliberate saves
/// and non-safety Filtros never change this decision.
public enum RecipeLinkNotOfferedReason: Equatable, Sendable {
    case allergensNotChecked
    case intolerances(Set<Allergen>)
    case intolerancesUnanswered(Set<Allergen>)

    public static func reason(
        for recipe: Recipe,
        intolerances: Set<Allergen>,
        hasAnsweredIntolerances: Bool
    ) -> Self? {
        guard case let .reviewed(allergens) = recipe.allergenReview else {
            return .allergensNotChecked
        }
        let matching = allergens.intersection(intolerances)
        if !matching.isEmpty { return .intolerances(matching) }
        if !hasAnsweredIntolerances && !allergens.isEmpty {
            return .intolerancesUnanswered(allergens)
        }
        return nil
    }
}
