import Foundation
import Testing
@testable import KartaCore

/// Assembling the payload handed to the native share sheet.
@Suite("Recipe share payload")
struct RecipeShareTests {

    private func recipe(_ id: String, _ name: String) -> Recipe {
        Recipe(
            id: id, name: name, heroPhoto: .local("test"), totalMinutes: 10, difficulty: .easy, servings: 4,
            tags: [], ingredients: [Ingredient(name: "x", quantity: "1")], steps: ["s"],
            allergenReview: .reviewed([])
        )
    }

    @Test("Payload identifies the recipe by name and a stable reference URL")
    func payloadHasNameAndReference() {
        let share = RecipeShare(baseURL: URL(string: "https://karta.app/r")!)
        let payload = share.payload(for: recipe("paella-01", "Seafood Paella"))

        #expect(payload.text.contains("Seafood Paella"))
        #expect(payload.url == URL(string: "https://karta.app/r/paella-01"))
    }

    @Test("The reference URL carries the recipe id")
    func referenceCarriesID() {
        let share = RecipeShare(baseURL: URL(string: "https://karta.app/r")!)
        let payload = share.payload(for: recipe("tortilla-09", "Spanish Omelette"))

        #expect(payload.url?.absoluteString.hasSuffix("/tortilla-09") == true)
    }

    @Test("A configured base URL keeps arbitrary ids in one path segment")
    func configuredBaseEncodesRecipeID() {
        let share = RecipeShare(baseURL: URL(string: "https://recipes.example/r")!)
        let payload = share.payload(for: recipe("a?b#c/d café", "Seafood Paella"))

        #expect(payload.url?.absoluteString == "https://recipes.example/r/a%3Fb%23c%2Fd%20caf%C3%A9")
    }

    @Test("Without a configured base URL, the payload remains text-only")
    func payloadWithoutBaseURLIsUsefulText() {
        let payload = RecipeShare().payload(for: recipe("paella-01", "Seafood Paella"))

        #expect(payload.text == "Check out Seafood Paella on Karta")
        #expect(payload.url == nil)
    }
}
