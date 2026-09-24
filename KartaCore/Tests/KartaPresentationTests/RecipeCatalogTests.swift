import Testing
import Foundation
import KartaCore
import KartaPresentation

@Suite("Seed recipe catalog")
struct RecipeCatalogTests {

    /// The editor-approved allergen set of every seed recipe. A change here is
    /// a safety decision and must go through the editor, never a refactor.
    private let expectedAllergens: [String: Set<Allergen>] = [
        "spanish-tortilla": [.egg],
        "quick-chicken-curry": [],
        "caesar-salad": [.gluten, .dairy, .egg, .fish],
        "pesto-pasta": [.gluten, .dairy, .nuts],
        "lentil-stew": [],
        "baked-salmon-with-lemon": [.fish],
        "banana-pancakes": [.gluten, .dairy, .egg],
        "vegetable-noodle-stir-fry": [.gluten],
    ]

    @Test("The seed holds exactly the eight expected recipes, each reviewed with its allergens")
    func seedRecipesAreReviewed() throws {
        let recipes = try SeedResourceAdapter().loadRecipes()

        #expect(recipes.count == 8)
        #expect(Dictionary(uniqueKeysWithValues: recipes.map { ($0.id, $0.allergenReview) })
            == expectedAllergens.mapValues { .reviewed($0) })
    }

    @Test("Seed dish names are in English")
    func dishNamesAreTranslated() throws {
        let names = try SeedResourceAdapter().loadRecipes().map(\.name)

        #expect(names == [
            "Spanish Tortilla",
            "Quick Chicken Curry",
            "Caesar Salad",
            "Pesto Pasta",
            "Lentil Stew",
            "Baked Salmon with Lemon",
            "Banana Pancakes",
            "Vegetable Noodle Stir-Fry",
        ])
    }

    @Test("Every seed recipe declares its servings")
    func seedRecipesDeclareServings() throws {
        let servings = Dictionary(uniqueKeysWithValues:
            try SeedResourceAdapter().loadRecipes().map { ($0.id, $0.servings) })

        #expect(servings == [
            "spanish-tortilla": 4,
            "quick-chicken-curry": 4,
            "caesar-salad": 2,
            "pesto-pasta": 4,
            "lentil-stew": 6,
            "baked-salmon-with-lemon": 2,
            "banana-pancakes": 2,
            "vegetable-noodle-stir-fry": 3,
        ])
    }

    @Test("Every seed recipe declares an editorial date")
    func seedRecipesDeclareEditorialDates() throws {
        let recipes = try SeedResourceAdapter().loadRecipes()

        #expect(recipes.allSatisfy { $0.editorialDate != .distantPast })
    }

    @Test("Seed quantities use US customary units, not metric")
    func seedQuantitiesAreUSCustomary() throws {
        let recipes = try SeedResourceAdapter().loadRecipes()
        let quantities = recipes.flatMap { recipe in
            recipe.ingredients.map(\.quantity)
                + recipe.steps.compactMap { $0.ingredient?.quantity }
        }
        let metric = try Regex(#"\d\s*(g|kg|ml|l)\b"#)

        #expect(quantities.filter { $0.contains(metric) }.isEmpty)
    }
}
