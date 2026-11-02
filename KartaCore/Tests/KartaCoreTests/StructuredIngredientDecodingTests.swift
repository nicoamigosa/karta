import Foundation
import Testing
import KartaCore

@Suite("Structured ingredient decoding")
struct StructuredIngredientDecodingTests {
    private func decode(_ ingredient: [String: Any]) throws -> Recipe {
        let object: [String: Any] = [
            "id": "onion-soup", "name": "Onion soup", "heroPhotoURL": "local:soup",
            "totalMinutes": 10, "difficulty": "easy", "servings": 2,
            "primaryCourse": "dinner", "contains": [], "ingredients": [ingredient],
            "steps": [["summary": "Chop", "detail": "Use a sharp knife.",
                       "ingredients": [["ingredientID": "onion", "quantity": "1 medium"]]]],
        ]
        return try JSONDecoder().decode(Recipe.self, from: JSONSerialization.data(withJSONObject: object))
    }

    private var onion: [String: Any] {
        ["id": "onion", "name": "Yellow onion", "purchaseKey": "yellow-onion", "shortName": "ingredient", "aisle": "produce",
         "quantity": ["amount": "1", "unit": "medium"]]
    }

    @Test("A missing, null or blank short name fails with its named error", arguments: ["missing", "null", "blank"])
    func missingShortName(value: String) {
        var ingredient = onion
        ingredient["shortName"] = value == "missing" ? nil : (value == "null" ? NSNull() as Any : "  ")
        #expect(throws: RecipeDecodingError.missingIngredientShortName(ingredientID: "onion")) {
            try decode(ingredient)
        }
    }

    @Test("A recipe decodes structured quantity, Clave de compra and Pasillo while steps stay text")
    func structuredIngredient() throws {
        let recipe = try decode(onion)
        let ingredient = try #require(recipe.ingredients.first)
        #expect(ingredient.structuredQuantity == .measured(try IngredientAmount("1"), unit: .medium))
        #expect(ingredient.quantity == "1 medium")
        #expect(ingredient.purchaseKey == "yellow-onion")
        #expect(ingredient.aisle == .produce)
        #expect(recipe.steps[0].ingredients[0].quantity == "1 medium")
        let restored = try JSONDecoder().decode(Recipe.self, from: JSONEncoder().encode(recipe))
        #expect(restored == recipe)
    }

    @Test("A missing quantity fails with a named error")
    func missingQuantity() {
        var ingredient = onion
        ingredient.removeValue(forKey: "quantity")
        #expect(throws: RecipeDecodingError.missingIngredientQuantity(ingredientID: "onion")) {
            try decode(ingredient)
        }
    }

    @Test("An unknown unit fails with its named error")
    func unknownUnit() {
        var ingredient = onion
        ingredient["quantity"] = ["amount": "1", "unit": "cups"]
        #expect(throws: RecipeDecodingError.unknownIngredientUnit(value: "cups")) { try decode(ingredient) }
    }

    @Test("An unknown unmeasured wording fails with its named error")
    func unknownWording() {
        var ingredient = onion
        ingredient["quantity"] = ["unmeasured": "for frying"]
        #expect(throws: RecipeDecodingError.unknownUnmeasuredQuantity(value: "for frying")) { try decode(ingredient) }
    }

    @Test("An unknown form fails with its named error")
    func unknownForm() {
        var ingredient = onion
        ingredient["quantity"] = ["amount": "1", "form": "chopped"]
        #expect(throws: RecipeDecodingError.unknownIngredientForm(value: "chopped")) { try decode(ingredient) }
    }

    @Test("An unknown Pasillo fails with its named error")
    func unknownAisle() {
        var ingredient = onion
        ingredient["aisle"] = "fruit"
        #expect(throws: RecipeDecodingError.unknownAisle(value: "fruit")) { try decode(ingredient) }
    }

    @Test("A missing, null or blank Clave de compra fails with its named error", arguments: ["missing", "null", "blank"])
    func missingPurchaseKey(value: String) {
        var ingredient = onion
        ingredient["purchaseKey"] = value == "missing" ? nil : (value == "null" ? NSNull() as Any : "  ")
        #expect(throws: RecipeDecodingError.missingPurchaseKey(ingredientID: "onion")) { try decode(ingredient) }
    }

    @Test("A missing Pasillo fails with its named error")
    func missingAisle() {
        var ingredient = onion
        ingredient.removeValue(forKey: "aisle")
        #expect(throws: RecipeDecodingError.missingAisle(ingredientID: "onion")) { try decode(ingredient) }
    }

    @Test("Non-positive amounts and invalid fractions fail with their named error", arguments: [
        "0", "-1", "0/3", "-1/3", "1/0", "1/-2", "1 0/2", "1 2/2", "1 1/0", "", " 1", "1 ", "1/2/3", "one", "1.5", "0 1/2", "9999999999999999999999",
    ])
    func invalidAmount(value: String) {
        var ingredient = onion
        ingredient["quantity"] = ["amount": value]
        #expect(throws: RecipeDecodingError.invalidIngredientAmount(value: value)) { try decode(ingredient) }
    }

    @Test("A quantity declares exactly one measured or unmeasured share", arguments: [
        #"{}"#, #"{"amount":"1","unmeasured":"to taste"}"#, #"{"unmeasured":"to taste","unit":"cup"}"#,
    ])
    func ambiguousQuantity(json: String) throws {
        var ingredient = onion
        ingredient["quantity"] = try JSONSerialization.jsonObject(with: Data(json.utf8))
        #expect(throws: RecipeDecodingError.invalidIngredientQuantity) { try decode(ingredient) }
    }

    @Test("The retired catalog string quantity is rejected")
    func retiredStringQuantity() {
        var ingredient = onion
        ingredient["quantity"] = "1 medium"
        #expect(throws: DecodingError.self) { try decode(ingredient) }
    }

    @Test("Generated units, forms and approximate weights cannot repeat ingredient-name words", arguments: [
        ("Medium onion", "unit", "medium"),
        ("Packed spinach", "form", "packed"),
        ("Yellow onion", "approximateWeight", "about one onion"),
    ])
    func repeatedGeneratedWord(name: String, field: String, value: String) {
        var ingredient = onion
        ingredient["name"] = name
        ingredient["quantity"] = ["amount": "1", field: value]
        #expect(throws: RecipeDecodingError.repeatedIngredientQuantityWord(
            recipeID: "onion-soup", recipeName: "Onion soup", ingredientID: "onion", stepIndex: nil
        )) { try decode(ingredient) }
    }
}
