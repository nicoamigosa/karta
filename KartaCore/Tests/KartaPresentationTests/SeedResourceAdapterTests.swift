import Foundation
import Testing
import KartaCore
import KartaPresentation

@Suite("Seed resource adapter")
struct SeedResourceAdapterTests {

    @Test("The public adapter loads the bundled clip catalog")
    func loadsBundledClips() throws {
        let adapter = SeedResourceAdapter()

        let clips = try adapter.loadTechniqueClips()

        #expect(clips.clip(for: CookingStep(text: "", clipID: "cuajar-tortilla")) != nil)
    }

    @Test("The public adapter propagates an unknown allergen from the recipe catalog")
    func rejectsUnknownRecipeAllergen() throws {
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
