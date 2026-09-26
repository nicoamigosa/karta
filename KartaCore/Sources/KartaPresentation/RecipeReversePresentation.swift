import KartaCore

/// The ingredient lines and step summaries shown on the reverse of a Card.
/// Full cooking instructions remain available only in the cooking session.
public struct RecipeReversePresentation: Equatable, Sendable {
    public let recipeID: String
    public let ingredients: [Ingredient]
    public let steps: [RecipeReverseStepPresentation]

    public init(recipe: Recipe, intolerances: Set<Allergen> = []) {
        recipeID = recipe.id
        ingredients = recipe.visibleIngredients(for: intolerances)
        steps = recipe.visibleSteps(for: intolerances)
            .filter { !$0.isOptional }
            .enumerated()
            .map { index, step in
                RecipeReverseStepPresentation(
                    number: index + 1,
                    summary: step.summary,
                    timerSeconds: step.timerSeconds,
                    clipID: step.clipID
                )
            }
    }
}

/// A required step's editor-written summary and the small cues shown beside it.
public struct RecipeReverseStepPresentation: Equatable, Sendable {
    public let number: Int
    public let summary: String
    public let timerSeconds: Int?
    public let clipID: String?

    public init(
        number: Int,
        summary: String,
        timerSeconds: Int? = nil,
        clipID: String? = nil
    ) {
        self.number = number
        self.summary = summary
        self.timerSeconds = timerSeconds
        self.clipID = clipID
    }
}
