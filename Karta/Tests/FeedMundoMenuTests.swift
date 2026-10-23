import Foundation
import Testing
import KartaCore
import KartaPresentation
@testable import Karta

@Suite("Feed header and Mundo menu")
struct FeedMundoMenuTests {
    private struct FixedClock: KartaClock {
        let now: Date
    }

    @MainActor
    private func makeStore() -> KartaStore {
        KartaStore(state: KartaState(
            onboarding: OnboardingState(
                intoleranceAnswer: .answered([]),
                householdSize: 4
            ),
            safetyProfile: SafetyProfile(intolerances: [])
        ))
    }

    @Test("The Mundo menu lists For You then Leftovers, in Mundo order")
    func menuRows() {
        let rows = MundoMenu.rows()
        #expect(rows.map(\.world) == World.allCases)
        #expect(rows.map(\.title) == ["For You", "Leftovers"])
        #expect(rows.map(\.subtitle) == ["Your deck for today", "Reuse what you cooked"])
        #expect(MundoMenu.title(for: .forYou) == "For You")
        #expect(MundoMenu.title(for: .leftovers) == "Leftovers")
    }

    @MainActor
    @Test("Switching Mundos preserves each Mundo's deck position")
    func mundoSwitchKeepsPosition() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let recipes = try SeedResourceAdapter().loadRecipes()
        let store = makeStore()
        let feed = try #require(store.feed(recipes: recipes, clock: FixedClock(now: now)))
        let cards = FeedDeckCard.cards(in: feed)
        let third = try #require(cards.dropFirst(2).first)
        let expectedIndex = try #require(cards.firstIndex { $0.id == third.id })

        // The deck settles on the third Card in For You…
        store.send(.recordView(recipeID: third.id, at: now))
        store.send(.setFeedAnchor(
            ScrollAnchor(recipeID: third.id, relativeOffset: 0),
            world: .forYou
        ))

        // …the user switches to Leftovers…
        store.send(.selectWorld(.leftovers))
        #expect(store.state.navigation.world == .leftovers)

        // …and back to For You: the deck lands on the same Card.
        store.send(.selectWorld(.forYou))
        #expect(store.state.navigation.world == .forYou)
        #expect(FeedDeckAnchor.initialIndex(
            cards: cards,
            navigation: store.state.navigation
        ) == expectedIndex)
    }

    @MainActor
    @Test("Switching Mundos never changes the applied filters or Intolerancias")
    func mundoSwitchKeepsFilters() {
        let store = makeStore()
        store.send(.filter(.setSafetyProfile(SafetyProfile(intolerances: [.dairy]))))
        store.send(.filter(.apply(FilterDraft(maxMinutes: 30, practicalTags: [.onePan]))))
        let filters = store.state.filterDraft
        let profile = store.state.safetyProfile

        store.send(.selectWorld(.leftovers))
        store.send(.selectWorld(.forYou))

        #expect(store.state.filterDraft == filters)
        #expect(store.state.safetyProfile == profile)
        #expect(store.state.appliedFilterCount == 2)
    }
}
