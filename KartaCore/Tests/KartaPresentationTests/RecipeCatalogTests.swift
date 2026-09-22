import Testing
import Foundation
import KartaCore
import KartaPresentation

@Suite("Seed recipe catalog")
struct RecipeCatalogTests {

    @Test("The catalog decoder rejects the legacy seed's unknown allergen")
    func legacySeedIsRejected() throws {
        do {
            _ = try SeedResourceAdapter().loadRecipes()
            Issue.record("Expected the legacy lactose tag to be rejected")
        } catch let error as RecipeDecodingError {
            #expect(error == .unknownAllergen(
                recipeID: "ensalada-cesar",
                recipeName: "Ensalada Cesar",
                value: "lactose"
            ))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}
