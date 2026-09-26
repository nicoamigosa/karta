import Foundation
import Testing
@testable import KartaCore

@Suite("Optional recipe content")
struct OptionalRecipeContentTests {

    @Test("An intolerance hides its optional ingredient and cooking step")
    func intoleranceHidesOptionalContent() {
        let recipe = recipe()

        #expect(recipe.visibleIngredients(for: [.dairy]).map(\.id) == ["flour"])
        #expect(recipe.visibleSteps(for: [.dairy]).map(\.text) == ["Bake the cake"])
        #expect(recipe.cookingSession(intolerances: [.dairy]).steps.map(\.text) == [
            "Bake the cake",
        ])
    }

    private func recipe() -> Recipe {
        Recipe(
            id: "optional-content",
            name: "Optional content",
            heroPhoto: .remote(URL(string: "https://img.karta.app/optional-content.jpg")!),
            totalMinutes: 30,
            difficulty: .easy,
            servings: 4,
            primaryCourse: .dessert,
            ingredients: [
                Ingredient(id: "flour", name: "All-purpose flour", quantity: "2 cups"),
                Ingredient(
                    id: "butter",
                    name: "Unsalted butter",
                    quantity: "1 tbsp",
                    isOptional: true,
                    allergens: [.dairy]
                ),
            ],
            steps: [
                CookingStep(
                    text: "Bake the cake",
                    summary: "Bake the cake",
                    ingredients: [StepIngredient(ingredientID: "flour", quantity: "2 cups")]
                ),
                CookingStep(
                    text: "Top with the butter",
                    summary: "Top with butter",
                    ingredients: [StepIngredient(ingredientID: "butter", quantity: "1 tbsp")],
                    isOptional: true
                ),
            ],
            allergenReview: .reviewed([])
        )
    }
}
