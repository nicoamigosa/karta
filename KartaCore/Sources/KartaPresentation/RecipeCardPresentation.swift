import KartaCore

/// The non-UI values the shell needs to render a recipe card. Formatting lives
/// here so the SwiftUI shell does not recreate domain presentation rules.
public struct RecipeCardPresentation: Equatable, Sendable {
    public let recipeID: String
    public let name: String
    public let servingsLabel: String
    public let householdSize: Int

    public init(recipe: Recipe, householdSize: Int) {
        precondition(householdSize > 0, "householdSize must be positive")
        self.recipeID = recipe.id
        self.name = recipe.name
        self.servingsLabel = "Serves \(recipe.servings)"
        self.householdSize = householdSize
    }
}
