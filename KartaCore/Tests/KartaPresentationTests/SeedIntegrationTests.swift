import Testing
import KartaCore
import KartaPresentation

/// Checks the resource boundary while the legacy seed is awaiting the
/// editorial rewrite in issue #32.
@Suite("Seed integration")
struct SeedIntegrationTests {

    @Test("The legacy seed is rejected at the typed allergen boundary")
    func legacySeedFailsLoudly() throws {
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

    @Test("The bundled clip catalog remains loadable")
    func clipsRemainLoadable() throws {
        let library = try SeedResourceAdapter().loadTechniqueClips()
        #expect(library.clip(for: CookingStep(text: "", clipID: "cuajar-tortilla")) != nil)
    }
}
