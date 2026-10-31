import LinkPresentation
import Testing
import UIKit
import KartaCore
import KartaPresentation
@testable import Karta

@MainActor
@Suite("Share sheet shell")
struct ShareSheetTests {
    private func payload() -> SharePayload {
        SharePayload(
            text: "Spanish Tortilla on Karta",
            url: URL(string: "https://karta.app/r/spanish-tortilla")!,
            title: "Spanish Tortilla",
            subtitle: "Serves 4 · 35 min · Easy",
            photo: .local("photos/spanish-tortilla")
        )
    }

    @Test("The link item hands the payload URL to the target app")
    func itemIsTheURL() {
        let payload = payload()
        let source = ShareLinkItemSource(payload: payload, image: nil)
        let controller = UIActivityViewController(
            activityItems: [source], applicationActivities: nil
        )

        #expect(source.activityViewControllerPlaceholderItem(controller) as? URL == payload.url)
        #expect(source.activityViewController(
            controller, itemForActivityType: .postToFacebook
        ) as? URL == payload.url)
        #expect(source.activityViewController(
            controller, itemForActivityType: nil
        ) as? URL == payload.url)
    }

    @Test("The sheet header keeps the two-line title and the Foto")
    func linkMetadata() {
        let payload = payload()
        let image = UIImage()
        let source = ShareLinkItemSource(payload: payload, image: image)
        let controller = UIActivityViewController(
            activityItems: [source], applicationActivities: nil
        )
        let metadata = source.activityViewControllerLinkMetadata(controller)

        #expect(metadata?.originalURL == payload.url)
        #expect(metadata?.url == payload.url)
        #expect(metadata?.title == "Spanish Tortilla\u{2028}Serves 4 · 35 min · Easy")
        #expect(metadata?.imageProvider != nil)
    }

    @Test("Without a base URL there is no payload; with one, the contract's")
    func payloadGating() {
        var state = KartaState(safetyProfile: SafetyProfile(intolerances: []))
        let recipe = Recipe(
            id: "spanish-tortilla",
            name: "Spanish Tortilla",
            heroPhoto: .local("photos/spanish-tortilla"),
            totalMinutes: 35,
            difficulty: .easy,
            servings: 4,
            primaryCourse: .dinner,
            ingredients: [
                Ingredient(id: "eggs", name: "Large eggs", quantity: "5")
            ],
            steps: [
                CookingStep(detail: "Fry until tender.", summary: "Fry")
            ],
            allergenReview: .reviewed([])
        )
        let off = KartaStore(state: state)
        #expect(ShareLinks.payload(for: recipe, in: off) == nil)

        state.shareBaseURL = URL(string: "https://karta.app")
        let on = KartaStore(state: state)
        #expect(ShareLinks.payload(for: recipe, in: on)
            == RecipeShare(baseURL: state.shareBaseURL).payload(for: recipe))
    }
}
