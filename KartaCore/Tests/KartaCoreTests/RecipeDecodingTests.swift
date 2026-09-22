import Testing
import Foundation
@testable import KartaCore

@Suite("Recipe decoding")
struct RecipeDecodingTests {

    @Test("Recipe decoding rejects a missing allergen review state")
    func missingAllergenReviewFails() throws {
        let json = """
        {
            "id": "unlabelled-recipe",
            "name": "Unlabelled recipe",
            "heroPhotoURL": "https://img.karta.app/unlabelled-recipe.jpg",
            "totalMinutes": 10,
            "difficulty": "easy",
            "tags": [],
            "ingredients": [{ "name": "x", "quantity": "1" }],
            "steps": ["paso"]
        }
        """

        do {
            _ = try JSONDecoder().decode(Recipe.self, from: Data(json.utf8))
            Issue.record("Expected decoding to reject the missing allergen review state")
        } catch let error as RecipeDecodingError {
            #expect(error == .missingAllergenReview(
                recipeID: "unlabelled-recipe",
                recipeName: "Unlabelled recipe"
            ))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("A catalog distinguishes reviewed-empty from unreviewed recipes")
    func catalogMixesReviewedAndUnreviewedRecipes() throws {
        let json = """
        [
            {
                "id": "reviewed-safe",
                "name": "Reviewed safe",
                "heroPhotoURL": "",
                "totalMinutes": 10,
                "difficulty": "easy",
                "tags": [],
                "contains": [],
                "ingredients": [{ "name": "x", "quantity": "1" }],
                "steps": ["s"]
            },
            {
                "id": "still-draft",
                "name": "Still draft",
                "heroPhotoURL": "",
                "totalMinutes": 10,
                "difficulty": "easy",
                "tags": [],
                "contains": null,
                "ingredients": [{ "name": "x", "quantity": "1" }],
                "steps": ["s"]
            }
        ]
        """

        let catalog = try RecipeCatalog.decode(from: Data(json.utf8))

        #expect(catalog.map(\.id) == ["reviewed-safe", "still-draft"])
        #expect(catalog[0].allergenReview == .reviewed([]))
        #expect(catalog[1].allergenReview == .unreviewed)

        let feed = FeedQuery.feed(
            recipes: catalog,
            views: [],
            recentWindow: testRecentWindow,
            clock: testClock,
            filters: FeedFilters()
        )
        #expect(feed.map(\.id) == ["reviewed-safe"])
    }

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
        #expect(recipe.allergenReview == .reviewed([.dairy]))
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
            "contains": [],
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
