import Testing
import KartaPresentation

@Suite("Bundled seed catalog")
struct SeedCatalogTests {
    @Test("The bundled catalog contains eight complete recipes")
    func catalogDecodes() throws {
        let recipes = try SeedResourceAdapter().loadRecipes()

        #expect(recipes.count == 8)
        #expect(recipes.allSatisfy { !$0.ingredients.isEmpty && !$0.steps.isEmpty })
    }
}
