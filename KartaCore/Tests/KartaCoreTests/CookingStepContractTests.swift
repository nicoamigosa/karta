import Foundation
import Testing
import KartaCore

@Suite("Cooking step contract")
struct CookingStepContractTests {
    private func decode(
        summary: String = "Cook the eggs",
        detail: String = "Use medium heat.",
        photo: String? = nil,
        quantity: String = "2",
        stepQuantity: String = "1"
    ) throws -> Recipe {
        var step: [String: Any] = [
            "summary": summary, "detail": detail,
            "ingredients": [["ingredientID": "eggs", "quantity": stepQuantity]],
        ]
        step["photo"] = photo
        let object: [String: Any] = [
            "id": "eggs", "name": "Eggs", "heroPhotoURL": "local:eggs",
            "totalMinutes": 10, "difficulty": "easy", "servings": 2,
            "primaryCourse": "breakfast", "contains": [],
            "ingredients": [["id": "eggs", "name": "Large eggs", "quantity": quantity]],
            "steps": [step],
        ]
        return try JSONDecoder().decode(Recipe.self, from: JSONSerialization.data(withJSONObject: object))
    }

    @Test("A step photo uses the same validated references as the recipe photo",
          arguments: ["local:eggs-step", "https://img.karta.app/step.jpg", "relative:steps/eggs.jpg"])
    func stepPhoto(reference: String) throws {
        let recipe = try decode(photo: reference)
        #expect(recipe.steps.first?.photo == (try MediaReference(validating: reference)))
        #expect(try decode().steps.first?.photo == nil)
    }

    @Test("An invalid step photo invalidates the recipe",
          arguments: ["", "local:", "relative:/step.jpg", "http://img.karta.app/step.jpg", "javascript:alert(1)"])
    func invalidPhoto(reference: String) {
        #expect(throws: MediaReference.ValidationError.self) { try decode(photo: reference) }
    }

    @Test("A Detalle identical to its Resumen invalidates the recipe")
    func repeatedDetail() {
        #expect(throws: RecipeDecodingError.repeatedStepDetail(recipeID: "eggs", recipeName: "Eggs", stepIndex: 0)) {
            try decode(detail: "Cook the eggs")
        }
    }

    @Test("A Resumen allows 36 characters but rejects 37, counting user-visible characters")
    func summaryLength() throws {
        #expect(try decode(summary: String(repeating: "é", count: 36)).steps[0].summary.count == 36)
        #expect(throws: RecipeDecodingError.overlongStepSummary(recipeID: "eggs", recipeName: "Eggs", stepIndex: 0)) {
            try decode(summary: String(repeating: "é", count: 37))
        }
    }

    @Test("Recipe Cantidad rejects repeated name words regardless of case or punctuation",
          arguments: ["2 LARGE", "2 (eggs)", "2 large-eggs"])
    func repeatedRecipeQuantity(quantity: String) {
        #expect(throws: RecipeDecodingError.repeatedIngredientQuantityWord(
            recipeID: "eggs", recipeName: "Eggs", ingredientID: "eggs", stepIndex: nil
        )) { try decode(quantity: quantity) }
    }

    @Test("Cantidad compares whole words, allowing a partial match")
    func quantityAllowsPartialWord() throws {
        #expect(try decode(quantity: "2 largely", stepQuantity: "1 egg").ingredients[0].quantity == "2 largely")
    }

    @Test("A Paso's Cantidad also rejects a word from its ingredient's name",
          arguments: ["1 LARGE", "1 (eggs)"])
    func repeatedStepQuantity(quantity: String) {
        #expect(throws: RecipeDecodingError.repeatedIngredientQuantityWord(
            recipeID: "eggs", recipeName: "Eggs", ingredientID: "eggs", stepIndex: 0
        )) { try decode(stepQuantity: quantity) }
    }

    @Test("The catalog requires detail rather than the retired text field")
    func retiredTextField() {
        let json = #"{"text":"Use medium heat.","summary":"Cook"}"#
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(CookingStep.self, from: Data(json.utf8))
        }
    }
}
