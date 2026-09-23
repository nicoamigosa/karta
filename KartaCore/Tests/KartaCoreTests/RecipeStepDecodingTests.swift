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
            "id": "r1", "name": "Mix", "heroPhotoURL": "https://img.karta.app/mix.jpg", "totalMinutes": 10,
            "difficulty": "easy", "servings": 4, "tags": [], "contains": [],
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

    @Test("Recipe decoding rejects a non-positive step duration with recipe context")
    func nonPositiveStepDurationFailsWithContext() throws {
        let json = """
        {
            "id": "zero-step-duration", "name": "Zero step duration",
            "heroPhotoURL": "https://img.karta.app/zero-step-duration.jpg",
            "totalMinutes": 10, "difficulty": "easy", "servings": 2,
            "tags": [], "contains": [],
            "ingredients": [{ "name": "x", "quantity": "1" }],
            "steps": [{ "text": "Wait", "timerSeconds": 0 }]
        }
        """

        do {
            _ = try JSONDecoder().decode(Recipe.self, from: Data(json.utf8))
            Issue.record("Expected a non-positive step duration to be rejected")
        } catch let error as RecipeDecodingError {
            #expect(error == .nonPositiveTimerSeconds(
                recipeID: "zero-step-duration",
                recipeName: "Zero step duration",
                stepIndex: 0,
                value: 0
            ))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Recipe decoding rejects empty step text with recipe context")
    func emptyStepTextFailsWithContext() throws {
        let json = """
        {
            "id": "missing-step-text", "name": "Missing step text",
            "heroPhotoURL": "https://img.karta.app/missing-step-text.jpg",
            "totalMinutes": 10, "difficulty": "easy", "servings": 2,
            "tags": [], "contains": [],
            "ingredients": [{ "name": "x", "quantity": "1" }],
            "steps": ["   "]
        }
        """

        do {
            _ = try JSONDecoder().decode(Recipe.self, from: Data(json.utf8))
            Issue.record("Expected empty step text to be rejected")
        } catch let error as RecipeDecodingError {
            #expect(error == .emptyStepText(
                recipeID: "missing-step-text",
                recipeName: "Missing step text",
                stepIndex: 0
            ))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Recipe decoding rejects an empty technique clip reference")
    func emptyStepClipIDFailsWithContext() throws {
        let json = """
        {
            "id": "missing-clip-id", "name": "Missing clip id",
            "heroPhotoURL": "https://img.karta.app/missing-clip-id.jpg",
            "totalMinutes": 10, "difficulty": "easy", "servings": 2,
            "tags": [], "contains": [],
            "ingredients": [{ "name": "x", "quantity": "1" }],
            "steps": [{ "text": "Cook", "clipID": " " }]
        }
        """

        do {
            _ = try JSONDecoder().decode(Recipe.self, from: Data(json.utf8))
            Issue.record("Expected an empty technique clip reference to be rejected")
        } catch let error as RecipeDecodingError {
            #expect(error == .emptyStepClipID(
                recipeID: "missing-clip-id",
                recipeName: "Missing clip id",
                stepIndex: 0
            ))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Recipe decoding rejects an empty step ingredient name")
    func emptyStepIngredientNameFailsWithContext() throws {
        let json = """
        {
            "id": "empty-step-ingredient-name", "name": "Empty step ingredient name",
            "heroPhotoURL": "https://img.karta.app/empty-step-ingredient-name.jpg",
            "totalMinutes": 10, "difficulty": "easy", "servings": 2,
            "tags": [], "contains": [],
            "ingredients": [{ "name": "Flour", "quantity": "1 cup" }],
            "steps": [{
                "text": "Cook",
                "ingredient": { "name": "  ", "quantity": "1 cup" }
            }]
        }
        """

        do {
            _ = try JSONDecoder().decode(Recipe.self, from: Data(json.utf8))
            Issue.record("Expected an empty step ingredient name to be rejected")
        } catch let error as RecipeDecodingError {
            #expect(error == .emptyStepIngredientName(
                recipeID: "empty-step-ingredient-name",
                recipeName: "Empty step ingredient name",
                stepIndex: 0
            ))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Recipe decoding rejects an empty step ingredient quantity")
    func emptyStepIngredientQuantityFailsWithContext() throws {
        let json = """
        {
            "id": "empty-step-ingredient-quantity", "name": "Empty step ingredient quantity",
            "heroPhotoURL": "https://img.karta.app/empty-step-ingredient-quantity.jpg",
            "totalMinutes": 10, "difficulty": "easy", "servings": 2,
            "tags": [], "contains": [],
            "ingredients": [{ "name": "Flour", "quantity": "1 cup" }],
            "steps": [{
                "text": "Cook",
                "ingredient": { "name": "Flour", "quantity": "  " }
            }]
        }
        """

        do {
            _ = try JSONDecoder().decode(Recipe.self, from: Data(json.utf8))
            Issue.record("Expected an empty step ingredient quantity to be rejected")
        } catch let error as RecipeDecodingError {
            #expect(error == .emptyStepIngredientQuantity(
                recipeID: "empty-step-ingredient-quantity",
                recipeName: "Empty step ingredient quantity",
                stepIndex: 0,
                ingredientName: "Flour"
            ))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Recipe decoding rejects a non-positive step ingredient quantity")
    func nonPositiveStepIngredientQuantityFailsWithContext() throws {
        let json = """
        {
            "id": "zero-step-ingredient-quantity", "name": "Zero step ingredient quantity",
            "heroPhotoURL": "https://img.karta.app/zero-step-ingredient-quantity.jpg",
            "totalMinutes": 10, "difficulty": "easy", "servings": 2,
            "tags": [], "contains": [],
            "ingredients": [{ "name": "Flour", "quantity": "1 cup" }],
            "steps": [{
                "text": "Cook",
                "ingredient": { "name": "Flour", "quantity": "0 cups" }
            }]
        }
        """

        do {
            _ = try JSONDecoder().decode(Recipe.self, from: Data(json.utf8))
            Issue.record("Expected a non-positive step ingredient quantity to be rejected")
        } catch let error as RecipeDecodingError {
            #expect(error == .nonPositiveStepIngredientQuantity(
                recipeID: "zero-step-ingredient-quantity",
                recipeName: "Zero step ingredient quantity",
                stepIndex: 0,
                ingredientName: "Flour",
                value: "0 cups"
            ))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("A recipe builds a cooking session over its own steps")
    func recipeBuildsCookingSession() throws {
        let recipe = Recipe(
            id: "r1", name: "Mix", heroPhoto: .local("test"), totalMinutes: 10, difficulty: .easy, servings: 4,
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
        let currentStep = try #require(session.currentStep)
        let ingredient = try #require(currentStep.ingredient)
        #expect(ingredient == Ingredient(name: "Onion", quantity: "1"))
    }
}
