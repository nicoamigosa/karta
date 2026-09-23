import Foundation
import Testing
import KartaCore
import KartaPresentation

@Suite("Onboarding state")
struct OnboardingPresentationTests {

    @Test("An unanswered intolerance question cannot produce a feed")
    func unansweredIntolerancesProduceNoFeed() {
        let state = OnboardingState(householdSize: 2)

        #expect(state.intoleranceAnswer == .unanswered)
        #expect(state.feed(
            recipes: [recipe("safe")],
            views: [],
            recentWindow: recentWindow,
            clock: clock
        ) == nil)
    }

    @Test("An explicit no-intolerances answer produces a safe feed")
    func answeredWithNoIntolerancesProducesFeed() throws {
        var state = OnboardingState(householdSize: 2)
        state.answerIntolerances([])

        let feed = try #require(state.feed(
            recipes: [recipe("safe")],
            views: [],
            recentWindow: recentWindow,
            clock: clock
        ))

        #expect(feed.newRecipes.map(\.id) == ["safe"])
        #expect(state.profile?.intolerances.isEmpty == true)
    }

    @Test("An invalid household size is rejected when onboarding accepts it")
    func invalidHouseholdSizeIsRejected() async {
        await #expect(processExitsWith: .failure) {
            _ = OnboardingState(householdSize: 0)
        }
    }

    @Test("A completed household profile supplies the recipe servings label")
    func completedProfileSuppliesServingsLabel() throws {
        var state = OnboardingState(householdSize: 2)
        state.answerIntolerances([])

        let card = try #require(state.cardPresentation(for: recipe("safe")))

        #expect(card.servingsLabel == "Serves 4")
        #expect(card.householdSize == 2)
    }

    private var clock: TestClock { TestClock(now: Date(timeIntervalSince1970: 1_000_000)) }
    private var recentWindow: TimeInterval { 7 * 24 * 60 * 60 }

    private func recipe(_ id: String) -> Recipe {
        Recipe(
            id: id,
            name: id,
            heroPhotoURL: "https://img.karta.app/\(id).jpg",
            totalMinutes: 30,
            difficulty: .easy,
            servings: 4,
            tags: [],
            ingredients: [Ingredient(name: "x", quantity: "1")],
            steps: ["Cook"],
            allergenReview: .reviewed([])
        )
    }
}

private struct TestClock: KartaClock {
    let now: Date
}
