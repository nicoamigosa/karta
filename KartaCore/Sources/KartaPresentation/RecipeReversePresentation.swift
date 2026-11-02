import KartaCore

/// The ingredient lines and step summaries shown on the reverse of a Card.
/// Full cooking instructions remain available only in the cooking session.
public struct RecipeReversePresentation: Equatable, Sendable {
    public let recipeID: String
    /// Saved tint survives the removal of unsaving from the reverse.
    public let isSaved: Bool
    public let isOnList: Bool
    public var pillTitle: String { !isSaved ? "Save" : isOnList ? "On your list" : "Add to list" }
    public var pillAction: KartaAction {
        !isSaved ? .saveRecipe(recipeID) : isOnList ? .shopping(.removeRecipe(recipeID)) : .shopping(.openAdd(recipeID))
    }
    /// A saved reverse has no save mutation; the shopping-list contract adds its action separately.
    public var saveAction: KartaAction? { isSaved ? nil : .saveRecipe(recipeID) }
    public let intoleranceNote: String?
    public let ingredients: [Ingredient]
    public let steps: [RecipeReverseStepPresentation]

    public init(recipe: Recipe, intolerances: Set<Allergen> = [], isSaved: Bool = false, isOnList: Bool = false) {
        recipeID = recipe.id
        self.isSaved = isSaved
        self.isOnList = isOnList
        intoleranceNote = IntoleranceWarning.note(recipe: recipe, intolerances: intolerances)
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
    /// The abbreviated timer cue, or `nil` when the step has no timer.
    public let timerLabel: String?
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
        self.timerLabel = timerSeconds.map { DurationText.shortFormat(seconds: $0) }
        self.clipID = clipID
    }
}
