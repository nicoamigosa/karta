import Foundation
import Testing
@testable import KartaCore

/// Assembling the payload handed to the native share sheet.
@Suite("Recipe share payload")
struct RecipeShareTests {

    private func recipe(_ id: String, _ name: String) -> Recipe {
        Recipe(
            id: id, name: name, heroPhotoURL: "", totalMinutes: 10, difficulty: .easy,
            tags: [], ingredients: [Ingredient(name: "x", quantity: "1")], steps: ["s"],
            allergenReview: .reviewed([])
        )
    }

    @Test("Payload identifies the recipe by name and a stable reference URL")
    func payloadHasNameAndReference() {
        let payload = RecipeShare.payload(for: recipe("paella-01", "Seafood Paella"))

        #expect(payload.text.contains("Seafood Paella"))
        #expect(payload.url == URL(string: "https://karta.app/r/paella-01"))
    }

    @Test("The reference URL carries the recipe id")
    func referenceCarriesID() {
        let payload = RecipeShare.payload(for: recipe("tortilla-09", "Spanish Omelette"))

        #expect(payload.url?.absoluteString.hasSuffix("/tortilla-09") == true)
    }
}
