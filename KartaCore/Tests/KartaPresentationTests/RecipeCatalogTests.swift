import Testing
import Foundation
import KartaCore
import KartaPresentation

@Suite("Seed recipe catalog")
struct RecipeCatalogTests {

    /// The editor-approved allergen set of every seed recipe. A change here is
    /// a safety decision and must go through the editor, never a refactor.
    private let expectedAllergens: [String: Set<Allergen>] = [
        "tortilla-de-papa": [.egg],
        "pollo-al-curry-rapido": [],
        "ensalada-cesar": [.gluten, .dairy, .egg, .fish],
        "pasta-al-pesto": [.gluten, .dairy, .nuts],
        "guiso-de-lentejas": [],
        "salmon-al-horno": [.fish],
        "panqueques-de-banana": [.gluten, .dairy, .egg],
        "wok-de-vegetales": [.gluten],
    ]

    @Test("The seed holds exactly the eight expected recipes, each reviewed with its allergens")
    func seedRecipesAreReviewed() throws {
        let recipes = try SeedResourceAdapter().loadRecipes()

        #expect(recipes.count == 8)
        #expect(Dictionary(uniqueKeysWithValues: recipes.map { ($0.id, $0.allergenReview) })
            == expectedAllergens.mapValues { .reviewed($0) })
    }

    @Test("Seed dish names stay in their original language")
    func dishNamesAreNotTranslated() throws {
        let names = try SeedResourceAdapter().loadRecipes().map(\.name)

        #expect(names == [
            "Tortilla de papa",
            "Pollo al curry rapido",
            "Ensalada Cesar",
            "Pasta al pesto",
            "Guiso de lentejas",
            "Salmon al horno con limon",
            "Panqueques de banana",
            "Wok de vegetales y fideos",
        ])
    }

    @Test("Every seed recipe declares its servings")
    func seedRecipesDeclareServings() throws {
        let servings = Dictionary(uniqueKeysWithValues:
            try SeedResourceAdapter().loadRecipes().map { ($0.id, $0.servings) })

        #expect(servings == [
            "tortilla-de-papa": 4,
            "pollo-al-curry-rapido": 4,
            "ensalada-cesar": 2,
            "pasta-al-pesto": 4,
            "guiso-de-lentejas": 6,
            "salmon-al-horno": 2,
            "panqueques-de-banana": 2,
            "wok-de-vegetales": 3,
        ])
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
