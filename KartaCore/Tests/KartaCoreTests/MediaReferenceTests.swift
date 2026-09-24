import Foundation
import Testing
@testable import KartaCore

@Suite("Media references")
struct MediaReferenceTests {

    @Test("A catalog preserves a local hero photo reference")
    func localHeroPhotoReferenceDecodes() throws {
        let json = """
        [{
            "id": "local-photo",
            "name": "Local photo",
            "heroPhotoURL": "local:photos/local-photo.jpg",
            "totalMinutes": 10,
            "difficulty": "easy",
            "servings": 2,
            "tags": [],
            "contains": [],
            "ingredients": [{ "name": "Potato", "quantity": "1" }],
            "steps": ["Cook"]
        }]
        """

        let recipe = try #require(try RecipeCatalog.decode(from: Data(json.utf8)).first)

        #expect(recipe.heroPhoto == .local("photos/local-photo.jpg"))
    }

    @Test("The catalog rejects a hero photo that is not an HTTPS or local reference")
    func invalidHeroPhotoReferenceFailsCatalogValidation() throws {
        let json = """
        [{
            "id": "invalid-photo",
            "name": "Invalid photo",
            "heroPhotoURL": "javascript:alert(1)",
            "totalMinutes": 10,
            "difficulty": "easy",
            "servings": 2,
            "tags": [],
            "contains": [],
            "ingredients": [{ "name": "Potato", "quantity": "1" }],
            "steps": ["Cook"]
        }]
        """

        do {
            _ = try RecipeCatalog.decode(from: Data(json.utf8))
            Issue.record("Expected an invalid media reference to be rejected")
        } catch let error as RecipeDecodingError {
            #expect(error == .invalidHeroPhotoReference(
                recipeID: "invalid-photo",
                recipeName: "Invalid photo",
                value: "javascript:alert(1)"
            ))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("The catalog rejects an empty local hero photo reference")
    func emptyLocalHeroPhotoReferenceFailsCatalogValidation() throws {
        let json = """
        [{
            "id": "empty-local-photo",
            "name": "Empty local photo",
            "heroPhotoURL": "local:",
            "totalMinutes": 10,
            "difficulty": "easy",
            "servings": 2,
            "tags": [],
            "contains": [],
            "ingredients": [{ "name": "Potato", "quantity": "1" }],
            "steps": ["Cook"]
        }]
        """

        do {
            _ = try RecipeCatalog.decode(from: Data(json.utf8))
            Issue.record("Expected an empty local media reference to be rejected")
        } catch let error as RecipeDecodingError {
            #expect(error == .invalidHeroPhotoReference(
                recipeID: "empty-local-photo",
                recipeName: "Empty local photo",
                value: "local:"
            ))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}
