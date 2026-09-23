import Testing
import Foundation
import KartaCore
import KartaPresentation

@Suite("Seed recipe catalog")
struct RecipeCatalogTests {

    @Test("A valid seed fixture contains exactly the expected recipe identities")
    func seedFixtureContainsExpectedRecipes() throws {
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
        let json = """
        [
            { "id": "tortilla-de-papa", "name": "Tortilla de papa", "heroPhotoURL": "https://img.karta.app/tortilla.jpg", "totalMinutes": 10, "difficulty": "easy", "servings": 2, "tags": [], "contains": [], "ingredients": [{ "name": "Potato", "quantity": "1" }], "steps": ["Cook"] },
            { "id": "pollo-al-curry-rapido", "name": "Pollo al curry rapido", "heroPhotoURL": "https://img.karta.app/pollo.jpg", "totalMinutes": 10, "difficulty": "easy", "servings": 2, "tags": [], "contains": [], "ingredients": [{ "name": "Chicken", "quantity": "1" }], "steps": ["Cook"] },
            { "id": "ensalada-cesar", "name": "Ensalada Cesar", "heroPhotoURL": "https://img.karta.app/ensalada.jpg", "totalMinutes": 10, "difficulty": "easy", "servings": 2, "tags": [], "contains": [], "ingredients": [{ "name": "Lettuce", "quantity": "1" }], "steps": ["Mix"] },
            { "id": "pasta-al-pesto", "name": "Pasta al pesto", "heroPhotoURL": "https://img.karta.app/pasta.jpg", "totalMinutes": 10, "difficulty": "easy", "servings": 2, "tags": [], "contains": [], "ingredients": [{ "name": "Pasta", "quantity": "1" }], "steps": ["Cook"] },
            { "id": "guiso-de-lentejas", "name": "Guiso de lentejas", "heroPhotoURL": "https://img.karta.app/guiso.jpg", "totalMinutes": 10, "difficulty": "easy", "servings": 2, "tags": [], "contains": [], "ingredients": [{ "name": "Lentils", "quantity": "1" }], "steps": ["Cook"] },
            { "id": "salmon-al-horno", "name": "Salmon al horno", "heroPhotoURL": "https://img.karta.app/salmon.jpg", "totalMinutes": 10, "difficulty": "easy", "servings": 2, "tags": [], "contains": [], "ingredients": [{ "name": "Salmon", "quantity": "1" }], "steps": ["Cook"] },
            { "id": "panqueques-de-banana", "name": "Panqueques de banana", "heroPhotoURL": "https://img.karta.app/panqueques.jpg", "totalMinutes": 10, "difficulty": "easy", "servings": 2, "tags": [], "contains": [], "ingredients": [{ "name": "Banana", "quantity": "1" }], "steps": ["Cook"] },
            { "id": "wok-de-vegetales", "name": "Wok de vegetales", "heroPhotoURL": "https://img.karta.app/wok.jpg", "totalMinutes": 10, "difficulty": "easy", "servings": 2, "tags": [], "contains": [], "ingredients": [{ "name": "Vegetables", "quantity": "1" }], "steps": ["Cook"] }
        ]
        """

        let recipes = try RecipeCatalog.decode(from: Data(json.utf8))

        #expect(recipes.count == expectedIDs.count)
        #expect(Set(recipes.map(\.id)) == expectedIDs)
        for expectedID in expectedIDs {
            let recipe = try #require(recipes.first { $0.id == expectedID })
            #expect(recipe.id == expectedID)
        }
    }

    @Test("The catalog decoder rejects the legacy seed before editorial migration")
    func legacySeedIsRejected() throws {
        do {
            _ = try SeedResourceAdapter().loadRecipes()
            Issue.record("Expected the legacy seed to be rejected")
        } catch let error as RecipeDecodingError {
            Issue.record("Unexpected typed recipe error: \(error)")
        } catch let error as DecodingError {
            guard case let .keyNotFound(key, _) = error else {
                Issue.record("Unexpected decoding error: \(error)")
                return
            }
            #expect(key.stringValue == "servings")
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}
