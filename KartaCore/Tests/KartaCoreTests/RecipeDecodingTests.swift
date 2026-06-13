import Testing
import Foundation
@testable import KartaCore

@Suite("Recipe decoding")
struct RecipeDecodingTests {

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
