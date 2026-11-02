import Foundation
import Testing
import KartaCore
import KartaPresentation

@Suite("Onboarding state")
struct OnboardingPresentationTests {

    @Test("The first tour advances to filters and later launches show filters alone")
    func tourLifecycle() {
        var state = OnboardingState()
        state.reduce(.coldLaunch(reduceMotion: false))
        #expect(state.tourStop == .cookbook)
        state.reduce(.tourDelayElapsed)
        #expect(state.tourStop == .world)
        state.reduce(.tourDelayElapsed)
        #expect(state.tourStop == .filters)
        #expect(state.hasShownFullTour)
        state.reduce(.tourTap)
        #expect(state.tourStop == nil)
        state.reduce(.coldLaunch(reduceMotion: false))
        #expect(state.tourStop == .filters)
        state.reduce(.filterButtonTapped)
        #expect(state.panel == .firstRun)
        #expect(state.tourStop == nil)
    }

    @MainActor
    @Test("The first-run panel stages both answers and commits them together at the top")
    func firstRunPanel() throws {
        let store = KartaStore(state: KartaState(safetyProfile: SafetyProfile(intolerances: [])))
        store.send(.onboarding(.setMine))
        #expect(store.state.onboarding.panel == .firstRun)
        #expect(store.state.onboarding.firstRunPanel.intoleranceLine == "Tap any you never eat, or none.")
        #expect(!store.state.onboarding.firstRunPanel.canShowCards)
        store.send(.onboarding(.showMyCards))
        #expect(store.state.onboarding.profile == nil)
        store.send(.onboarding(.toggleFirstRunAllergen(.dairy)))
        #expect(store.state.onboarding.firstRunPanel.intoleranceLine == "Dairy will never show up. Change it anytime here.")
        store.send(.onboarding(.chooseFirstRunHousehold(5)))
        store.send(.onboarding(.closePanel))
        #expect(store.state.onboarding.profile == nil)
        #expect(store.state.onboarding.householdSize == nil)
        store.send(.onboarding(.setMine))
        #expect(store.state.onboarding.firstRunPanel.canShowCards)
        store.send(.setFeedAnchor(ScrollAnchor(recipeID: "safe", relativeOffset: 0), world: .forYou))
        store.send(.onboarding(.showMyCards))
        #expect(store.state.onboarding.profile == OnboardingProfile(intolerances: [.dairy], householdSize: 5))
        #expect(store.state.onboarding.panel == nil)
        #expect(store.state.onboarding.banner == nil)
        #expect(store.state.navigation.anchor(for: .forYou) == nil)
    }

    @MainActor
    @Test("An unanswered intolerance question offers the safe deck")
    func unansweredIntolerancesProduceSafeDeck() {
        let store = KartaStore(state: KartaState(
            onboarding: OnboardingState(householdSize: 2),
            safetyProfile: SafetyProfile(intolerances: [])
        ))

        #expect(store.state.onboarding.intoleranceAnswer == .unanswered)
        #expect(store.feed(
            recipes: [recipe("safe")],
            views: [],
            recentWindow: recentWindow,
            clock: clock
        )?.recipes.map(\.id) == ["safe"])
    }

    @MainActor
    @Test("An explicit no-intolerances answer produces a safe feed")
    func answeredWithNoIntolerancesProducesFeed() throws {
        let store = KartaStore(state: KartaState(
            onboarding: OnboardingState(householdSize: 2),
            safetyProfile: SafetyProfile(intolerances: [])
        ))
        store.send(.onboarding(.answerIntolerances([])))

        let feed = try #require(store.feed(
            recipes: [recipe("safe")],
            views: [],
            recentWindow: recentWindow,
            clock: clock
        ))

        #expect(feed.newRecipes.map(\.id) == ["safe"])
        #expect(store.state.onboarding.profile?.intolerances.isEmpty == true)
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
            heroPhoto: .remote(URL(string: "https://img.karta.app/\(id).jpg")!),
            totalMinutes: 30,
            difficulty: .easy,
            servings: 4,
            primaryCourse: .dinner,
            ingredients: [Ingredient(name: "x", quantity: "1")],
            steps: ["Cook"],
            allergenReview: .reviewed([])
        )
    }
}

private struct TestClock: KartaClock {
    let now: Date
}
