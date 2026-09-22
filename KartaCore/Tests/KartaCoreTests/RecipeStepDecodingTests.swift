import Foundation
import Testing
@testable import KartaCore

/// A recipe's steps are structured (text + optional ingredient/timer/clip) but
/// decode backward-compatibly from a bare string. This is the seam that lets the
/// feed/detail and cooking mode share one step model.
@Suite("Recipe step decoding")
struct RecipeStepDecodingTests {

    @Test("A bare-string step decodes as text-only")
    func bareStringStep() throws {
        let step = try JSONDecoder().decode(CookingStep.self, from: Data("\"Stir well\"".utf8))

        #expect(step == CookingStep(text: "Stir well"))
    }

    @Test("A structured step decodes its ingredient, timer and clip")
    func structuredStep() throws {
        let json = """
        {
            "text": "Simmer the sauce",
            "ingredient": { "name": "Tomato", "quantity": "400 g" },
            "timerSeconds": 600,
            "clipID": "reduce-sauce"
        }
        """
        let step = try JSONDecoder().decode(CookingStep.self, from: Data(json.utf8))

        #expect(step.text == "Simmer the sauce")
        #expect(step.ingredient == Ingredient(name: "Tomato", quantity: "400 g"))
        #expect(step.timerSeconds == 600)
        #expect(step.clipID == "reduce-sauce")
    }

    @Test("A recipe decodes a mix of bare and structured steps")
    func mixedStepsInRecipe() throws {
        let json = """
        {
            "id": "r1", "name": "Mix", "heroPhotoURL": "", "totalMinutes": 10,
            "difficulty": "easy", "tags": [], "contains": [],
            "ingredients": [{ "name": "x", "quantity": "1" }],
            "steps": [
                "Chop the onion",
                { "text": "Fry it", "timerSeconds": 120 }
            ]
        }
        """
        let recipe = try JSONDecoder().decode(Recipe.self, from: Data(json.utf8))

        #expect(recipe.steps.count == 2)
        #expect(recipe.steps[0] == CookingStep(text: "Chop the onion"))
        #expect(recipe.steps[1].timerSeconds == 120)
    }

    @Test("A recipe builds a cooking session over its own steps")
    func recipeBuildsCookingSession() {
        let recipe = Recipe(
            id: "r1", name: "Mix", heroPhotoURL: "", totalMinutes: 10, difficulty: .easy,
            tags: [], ingredients: [Ingredient(name: "Onion", quantity: "1")],
            steps: [
                CookingStep(text: "Chop", ingredient: Ingredient(name: "Onion", quantity: "1")),
                "Serve",
            ],
            allergenReview: .reviewed([])
        )

        let session = recipe.cookingSession()

        #expect(session.recipeID == "r1")
        #expect(session.steps == recipe.steps)
        #expect(session.currentStep?.ingredient == Ingredient(name: "Onion", quantity: "1"))
    }
}
