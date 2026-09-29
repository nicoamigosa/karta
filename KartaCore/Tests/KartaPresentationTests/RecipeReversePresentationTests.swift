import Testing
import KartaCore
import KartaPresentation

@Suite("Recipe reverse presentation")
struct RecipeReversePresentationTests {

    @Test("A reverse step exposes its timer as a short label")
    func reverseStepFormatsTimerLabel() {
        let step = RecipeReverseStepPresentation(
            number: 1,
            summary: "Cook",
            timerSeconds: 720
        )
        let stepWithoutTimer = RecipeReverseStepPresentation(number: 2, summary: "Serve")

        #expect(step.timerLabel == "12 min")
        #expect(step.timerSeconds == 720)
        #expect(stepWithoutTimer.timerLabel == nil)
    }

    @Test("The reverse shows ingredient lines and required-step summaries only")
    func reverseUsesSummariesAndOmitsOptionalSteps() {
        let recipe = recipe()
        let reverse = RecipeReversePresentation(recipe: recipe)

        #expect(reverse.ingredients.map(\.id) == ["sauce", "optional-dairy", "optional-garnish"]
            + Allergen.allCases.dropFirst().map { "optional-\($0.rawValue)" })
        #expect(reverse.ingredients.map(\.isOptional) == [false]
            + Array(repeating: true, count: Allergen.allCases.count + 1))
        #expect(reverse.steps.map(\.number) == [1])
        #expect(reverse.steps.map(\.summary) == ["Cook the sauce"])
        #expect(recipe.cookingSession().steps.map(\.text)
            == ["Cook the sauce slowly until glossy", "Finish with basil"]
                + Allergen.allCases.map { "Add optional \($0.rawValue)" })
    }

    @Test("Every intolerance combination hides matching optional ingredients and their steps")
    func everyIntoleranceCombinationFiltersOptionalContent() {
        let recipe = recipe()
        let allergens = Allergen.allCases

        for mask in 0..<(1 << allergens.count) {
            let intolerances = Set(allergens.enumerated().compactMap { index, allergen in
                (mask & (1 << index)) != 0 ? allergen : nil
            })
            let expectedIngredientIDs = ["sauce"]
                + (intolerances.contains(.dairy) ? [] : ["optional-dairy"])
                + ["optional-garnish"]
                + allergens.dropFirst().compactMap { allergen in
                    intolerances.contains(allergen) ? nil : "optional-\(allergen.rawValue)"
                }
            let expectedSessionSteps = ["Cook the sauce slowly until glossy", "Finish with basil"]
                + allergens.compactMap { allergen in
                    intolerances.contains(allergen) ? nil : "Add optional \(allergen.rawValue)"
                }
            let reverse = RecipeReversePresentation(recipe: recipe, intolerances: intolerances)
            let session = recipe.cookingSession(intolerances: intolerances)

            #expect(reverse.ingredients.map(\.id) == expectedIngredientIDs)
            #expect(reverse.steps.map(\.summary) == ["Cook the sauce"])
            #expect(session.steps.map(\.text) == expectedSessionSteps)
        }
    }

    private func recipe() -> Recipe {
        let optionalIngredients = Allergen.allCases.map { allergen in
            Ingredient(
                id: "optional-\(allergen.rawValue)",
                name: "Optional \(allergen.rawValue)",
                quantity: "1 tbsp",
                isOptional: true,
                allergens: [allergen]
            )
        }
        let optionalSteps = Allergen.allCases.map { allergen in
            CookingStep(
                text: "Add optional \(allergen.rawValue)",
                summary: "Add \(allergen.rawValue)",
                ingredients: [
                    StepIngredient(
                        ingredientID: "optional-\(allergen.rawValue)",
                        quantity: "1 tbsp"
                    ),
                ],
                isOptional: true
            )
        }

        return Recipe(
            id: "reverse-safety",
            name: "Reverse safety",
            heroPhoto: .local("reverse-safety"),
            totalMinutes: 20,
            difficulty: .easy,
            servings: 2,
            primaryCourse: .dinner,
            ingredients: [
                Ingredient(id: "sauce", name: "Tomato sauce", quantity: "2 cups"),
                optionalIngredients[0],
                Ingredient(
                    id: "optional-garnish",
                    name: "Fresh basil",
                    quantity: "2 leaves",
                    isOptional: true,
                    allergens: []
                ),
            ] + Array(optionalIngredients.dropFirst()),
            steps: [
                CookingStep(
                    text: "Cook the sauce slowly until glossy",
                    summary: "Cook the sauce",
                    ingredients: [StepIngredient(ingredientID: "sauce", quantity: "2 cups")]
                ),
                CookingStep(
                    text: "Finish with basil",
                    summary: "Finish with basil",
                    ingredients: [
                        StepIngredient(ingredientID: "optional-garnish", quantity: "2 leaves"),
                    ],
                    isOptional: true
                ),
            ] + optionalSteps,
            allergenReview: .reviewed([])
        )
    }
}
