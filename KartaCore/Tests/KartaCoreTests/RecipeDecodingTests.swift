import Testing
import Foundation
@testable import KartaCore

@Suite("Recipe decoding")
struct RecipeDecodingTests {

    @Test("Allergen decoding is closed and normalizes input")
    func allergenVocabularyNormalizesInput() throws {
        #expect(Allergen(rawValue: " dairy ") == .dairy)
        #expect(Allergen(rawValue: "DAIRY") == .dairy)
        #expect(Allergen(rawValue: "lactose") == nil)

        let json = """
        {
            "id": "normalized-allergens",
            "name": "Normalized allergens",
            "heroPhotoURL": "https://img.karta.app/normalized-allergens.jpg",
            "totalMinutes": 10,
            "difficulty": "easy",
            "tags": [],
            "contains": [" DaIrY "],
            "ingredients": [{ "name": "x", "quantity": "1" }],
            "steps": ["paso"]
        }
        """

        let recipe = try JSONDecoder().decode(Recipe.self, from: Data(json.utf8))
        #expect(recipe.contains == [.dairy])
    }

    @Test("Recipe decoding names an unknown allergen and its recipe")
    func unknownAllergenFailsWithContext() throws {
        let json = """
        {
            "id": "stale-pesto",
            "name": "Stale pesto",
            "heroPhotoURL": "https://img.karta.app/stale-pesto.jpg",
            "totalMinutes": 10,
            "difficulty": "easy",
            "tags": [],
            "contains": ["lactose"],
            "ingredients": [{ "name": "x", "quantity": "1" }],
            "steps": ["paso"]
        }
        """

        do {
            _ = try JSONDecoder().decode(Recipe.self, from: Data(json.utf8))
            Issue.record("Expected decoding to reject the unknown allergen")
        } catch let error as RecipeDecodingError {
            #expect(error == .unknownAllergen(
                recipeID: "stale-pesto",
                recipeName: "Stale pesto",
                value: "lactose"
            ))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    /// Tracer bullet: proves the data-model → JSON decode path end to end.
    /// A single recipe must decode with the fields a feed card and the
    /// detail screen depend on, including ingredient quantities and ordered steps.
    @Test("A recipe decodes from JSON with its core fields")
    func decodesSingleRecipe() throws {
        let json = """
        {
            "id": "tortilla-de-papa",
            "name": "Tortilla de papa",
            "heroPhotoURL": "https://img.karta.app/tortilla.jpg",
            "totalMinutes": 35,
            "difficulty": "easy",
            "tags": ["one-pan", "vegetarian"],
            "ingredients": [
                { "name": "Papa", "quantity": "4 unidades" },
                { "name": "Huevo", "quantity": "5 unidades" }
            ],
            "steps": [
                "Pelar y cortar las papas en rodajas finas.",
                "Freír a fuego medio hasta que estén tiernas."
            ]
        }
        """

        let recipe = try JSONDecoder().decode(Recipe.self, from: Data(json.utf8))

        #expect(recipe.id == "tortilla-de-papa")
        #expect(recipe.name == "Tortilla de papa")
        #expect(recipe.totalMinutes == 35)
        #expect(recipe.difficulty == .easy)
        #expect(recipe.tags == ["one-pan", "vegetarian"])
        #expect(recipe.ingredients.count == 2)
        #expect(recipe.ingredients.first?.name == "Papa")
        #expect(recipe.ingredients.first?.quantity == "4 unidades")
        #expect(recipe.steps.count == 2)
    }
}
