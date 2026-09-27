import Foundation
import Testing
import KartaCore
import KartaPresentation
@testable import Karta

@Suite("Feed Card deck")
struct FeedDeckTests {
    private struct FixedClock: KartaClock {
        let now: Date
    }

    @MainActor
    @Test("Deck cards preserve the store feed order and seen state")
    func cardsFollowStoreFeed() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let recipes = try SeedResourceAdapter().loadRecipes()
        let store = KartaStore(state: KartaState(
            onboarding: OnboardingState(
                intoleranceAnswer: .answered([]),
                householdSize: 4
            ),
            safetyProfile: SafetyProfile(intolerances: [])
        ))

        let initialFeed = try #require(store.feed(
            recipes: recipes,
            clock: FixedClock(now: now)
        ))
        let initialCards = FeedDeckCard.cards(in: initialFeed)
        let firstCard = try #require(initialCards.first)

        #expect(initialCards.count == recipes.count)
        #expect(initialCards.allSatisfy { !$0.alreadySeen })

        store.send(.recordView(recipeID: firstCard.id, at: now))

        let updatedFeed = try #require(store.feed(
            recipes: recipes,
            clock: FixedClock(now: now)
        ))
        let updatedCards = FeedDeckCard.cards(in: updatedFeed)

        #expect(updatedCards.last?.id == firstCard.id)
        #expect(updatedCards.last?.alreadySeen == true)
    }

    @Test("Vertical gestures move one Card and stop at deck edges")
    func verticalNavigation() {
        #expect(DeckNavigator.destination(
            from: 1,
            translation: CGSize(width: 0, height: -KartaDesign.deck.swipeThreshold),
            predictedTranslation: CGSize(
                width: 0,
                height: -KartaDesign.deck.swipeThreshold
            ),
            cardCount: 4
        ) == 2)
        #expect(DeckNavigator.destination(
            from: 1,
            translation: CGSize(width: 0, height: KartaDesign.deck.swipeThreshold),
            predictedTranslation: CGSize(
                width: 0,
                height: KartaDesign.deck.swipeThreshold
            ),
            cardCount: 4
        ) == 0)
        #expect(DeckNavigator.destination(
            from: 1,
            translation: CGSize(width: 0, height: 39),
            predictedTranslation: CGSize(width: 0, height: 39),
            cardCount: 4
        ) == 1)
        #expect(DeckNavigator.destination(
            from: 0,
            translation: CGSize(width: 0, height: 200),
            predictedTranslation: CGSize(width: 0, height: 200),
            cardCount: 4
        ) == 0)
        #expect(DeckNavigator.destination(
            from: 3,
            translation: CGSize(width: 0, height: -200),
            predictedTranslation: CGSize(width: 0, height: -200),
            cardCount: 4
        ) == 3)
        #expect(DeckNavigator.destination(
            from: 1,
            translation: CGSize(width: 200, height: 20),
            predictedTranslation: CGSize(width: 300, height: -100),
            cardCount: 4
        ) == 1)
        #expect(DeckNavigator.destination(
            from: 1,
            translation: CGSize(width: 40, height: 40),
            predictedTranslation: CGSize(width: 40, height: -100),
            cardCount: 4
        ) == 1)
    }

    @MainActor
    @Test("Card rank uses presentation-ready minutes and unit")
    func cardRankPresentation() throws {
        let recipes = try SeedResourceAdapter().loadRecipes()
        let recipe = try #require(recipes.first { $0.name == "Spanish Tortilla" })
        let store = KartaStore(state: KartaState(
            onboarding: OnboardingState(
                intoleranceAnswer: .answered([]),
                householdSize: 4
            ),
            safetyProfile: SafetyProfile(intolerances: [])
        ))
        let presentation = try #require(store.cardPresentation(for: recipe))

        #expect(presentation.rankValue == "35")
        #expect(presentation.rankUnit == "MIN")
    }

    @Test("Signed-off deck values come from shared style tokens")
    func styleTokens() {
        #expect(KartaDesign.radius.card == 26)
        #expect(KartaDesign.radius.photo == 18)
        #expect(KartaDesign.deck.swipeThreshold == 40)
        #expect(KartaDesign.deck.motionDuration == 0.46)
        #expect(KartaDesign.deck.faceRevealDelay == 0.12)
        #expect(KartaDesign.deck.leavingTranslationScale == 1.15)
        #expect(KartaDesign.deck.leavingRotation == -9)
        #expect(KartaDesign.deck.nudgeDuration == 2.4)
        #expect(abs(KartaDesign.deck.nudgeLiftDuration - 0.336) < 0.0001)
        #expect(abs(KartaDesign.deck.nudgeSettleDuration - 0.384) < 0.0001)
        #expect(abs(KartaDesign.deck.nudgeRestDuration - 1.68) < 0.0001)
        #expect(
            abs(
                KartaDesign.deck.nudgeLiftDuration
                + KartaDesign.deck.nudgeSettleDuration
                + KartaDesign.deck.nudgeRestDuration
                - KartaDesign.deck.nudgeDuration
            ) < 0.0001
        )
        #expect(KartaDesign.type.displaySoftAxis == 0x534F4654)
        #expect(KartaDesign.type.displayWeightAxis == 0x77676874)
        #expect(KartaDesign.type.displaySoft == 100)
        #expect(KartaDesign.type.wordmarkTracking == -0.8)
        #expect(KartaDesign.type.rankUnitTracking == 1.2)
        #expect(KartaDesign.type.cardTitleTracking == -0.6)
        #expect(KartaDesign.elevation.backFrameLineWidth == 1)
        #expect(KartaDesign.layout.onboardingMaxWidth == 460)
    }
}
