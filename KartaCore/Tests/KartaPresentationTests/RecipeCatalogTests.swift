import Testing
import Foundation
import KartaCore
import KartaPresentation

@Suite("Seed recipe catalog")
struct RecipeCatalogTests {

    @Test("The seed contains exactly the expected recipe identities")
    func seedContainsExpectedRecipes() throws {
        let expectedIDs: Set<String> = [
            "tortilla-de-papa",
            "pollo-al-curry-rapido",
            "ensalada-cesar",
            "pasta-al-pesto",
            "guiso-de-lentejas",
            "salmon-al-horno",
            "panqueques-de-banana",
            "wok-de-vegetales",
        ]
        let recipes = try SeedResourceAdapter().loadRecipes()

        #expect(recipes.count == expectedIDs.count)
        #expect(Set(recipes.map(\.id)) == expectedIDs)
        for expectedID in expectedIDs {
            let recipe = try #require(recipes.first { $0.id == expectedID })
            #expect(recipe.id == expectedID)
        }
    }
}
