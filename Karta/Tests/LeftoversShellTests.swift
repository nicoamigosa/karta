import CoreGraphics
import Foundation
import Testing
import KartaCore
import KartaPresentation
@testable import Karta

@Suite("Leftovers Mundo in the shell")
struct LeftoversShellTests {
    private struct FixedClock: KartaClock {
        let now: Date
    }

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    @MainActor
    private func makeStore(
        world: World = .forYou,
        cooks: [CookEntry] = [],
        recipes: [Recipe]
    ) -> KartaStore {
        KartaStore(
            state: KartaState(
                onboarding: OnboardingState(intoleranceAnswer: .answered([]), householdSize: 2),
                cookHistory: cooks,
                navigation: AppNavigationState(world: world),
                safetyProfile: SafetyProfile(intolerances: [])
            ),
            recipes: recipes,
            clock: FixedClock(now: now)
        )
    }

    @MainActor
    @Test("See on the toast switches the Mundo to Leftovers, at the top")
    func seeSwitchesToLeftoversAtTop() throws {
        let recipes = try SeedResourceAdapter().loadRecipes()
        let clock = FixedClock(now: now)
        let tortilla = try #require(recipes.first { $0.id == "spanish-tortilla" })
        let store = makeStore(recipes: recipes)

        // An earlier Leftovers position that See must not restore.
        store.send(.setFeedAnchor(ScrollAnchor(recipeID: "banana-pancakes", relativeOffset: 0), world: .leftovers))
        store.send(.startCooking(tortilla, startedAt: now.timeIntervalSince1970 - 1800))
        while store.session?.isOnFinish == false {
            store.send(.nextStep(now: now.timeIntervalSince1970 - 60))
        }
        store.send(.respond(.thumbsUp))
        store.send(.exitCooking)
        let keyBefore = FeedDeckIdentity.key(world: store.state.navigation.world, filters: store.state.effectiveFeedFilters)
        _ = try #require(store.state.leftoversToast)

        store.send(LeftoversToastResponse.see)

        #expect(store.state.navigation.world == .leftovers)
        #expect(store.state.leftoversToast == nil)
        // The surface rebuilds for the new Mundo and the deck starts on its first Card.
        #expect(FeedDeckIdentity.key(world: store.state.navigation.world, filters: store.state.effectiveFeedFilters) != keyBefore)
        let cards = FeedDeckCard.cards(in: store.leftoversFeed(recipes: recipes, clock: clock))
        #expect(cards.count > 1)
        #expect(FeedDeckAnchor.initialIndex(cards: cards, navigation: store.state.navigation) == 0)
    }

    @MainActor
    @Test("The toast's timeout dismisses it and keeps For You")
    func toastTimeoutStaysOnForYou() throws {
        let recipes = try SeedResourceAdapter().loadRecipes()
        let tortilla = try #require(recipes.first { $0.id == "spanish-tortilla" })
        let store = makeStore(recipes: recipes)
        store.send(.startCooking(tortilla, startedAt: now.timeIntervalSince1970 - 1800))
        while store.session?.isOnFinish == false {
            store.send(.nextStep(now: now.timeIntervalSince1970 - 60))
        }
        store.send(.respond(.thumbsUp))
        store.send(.exitCooking)
        _ = try #require(store.state.leftoversToast)

        store.send(LeftoversToastResponse.dismissed)

        #expect(store.state.leftoversToast == nil)
        #expect(store.state.navigation.world == .forYou)
    }

    @MainActor
    @Test("Go to For You on a Leftovers empty state switches the Mundo", arguments: [0.0, 9.0])
    func goToForYouSwitchesMundo(daysAgo: Double) throws {
        let recipes = try SeedResourceAdapter().loadRecipes()
        let cooks = daysAgo == 0 ? [] : [CookEntry(recipeID: "spanish-tortilla", date: now.addingTimeInterval(-daysAgo * 86_400))]
        let store = makeStore(world: .leftovers, cooks: cooks, recipes: recipes)
        let empty = store.leftoversEmptyState(recipes: recipes, clock: FixedClock(now: now))
        #expect(empty.primaryButtonTitle == "Go to For You")

        let action = try #require(LeftoversEmptyStateAction.primary(for: empty))
        guard case .send(let sent) = action else {
            Issue.record("Go to For You must send a store action")
            return
        }
        store.send(sent)

        #expect(store.state.navigation.world == .forYou)
    }

    @Test("Change filters opens the shell's panel; Clear all filters sends the store's reset")
    func filtersEmptyStateActions() {
        let empty = LeftoversEmptyState.noMatchForFilters(summary: "No leftover recipe is ready in 20 min.", keptIntolerances: nil)
        guard case .openFilters = LeftoversEmptyStateAction.primary(for: empty) else {
            Issue.record("Change filters must open the filter panel")
            return
        }
        guard case .send = LeftoversEmptyStateAction.secondary(for: empty) else {
            Issue.record("Clear all filters must send the store's action")
            return
        }
    }

    @Test("Only a vertical swipe up past the threshold asks to pass the last Card")
    func forwardSwipe() {
        let threshold = KartaDesign.deck.swipeThreshold
        #expect(DeckNavigator.isForwardSwipe(
            translation: CGSize(width: 0, height: -threshold),
            predictedTranslation: CGSize(width: 0, height: -threshold)
        ))
        #expect(!DeckNavigator.isForwardSwipe(
            translation: CGSize(width: 0, height: threshold),
            predictedTranslation: CGSize(width: 0, height: threshold)
        ))
        #expect(!DeckNavigator.isForwardSwipe(
            translation: CGSize(width: -threshold * 2, height: -threshold),
            predictedTranslation: CGSize(width: -threshold * 2, height: -threshold)
        ))
    }
}
