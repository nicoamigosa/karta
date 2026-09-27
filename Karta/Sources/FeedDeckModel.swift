import CoreGraphics
import KartaCore
import KartaPresentation

struct FeedDeckCard: Identifiable, Equatable {
    let recipe: Recipe
    var alreadySeen: Bool

    var id: String { recipe.id }

    static func cards(in feed: Feed) -> [FeedDeckCard] {
        feed.newRecipes.map { FeedDeckCard(recipe: $0, alreadySeen: false) }
            + feed.alreadySeenRecipes.map { FeedDeckCard(recipe: $0, alreadySeen: true) }
    }
}

/// Resolves the deck's initial position from the session scroll anchor stored
/// in `AppNavigationState` (ADR 0009). A missing or stale anchor starts at 0.
enum FeedDeckAnchor {
    static func initialIndex(cards: [FeedDeckCard], navigation: AppNavigationState) -> Int {
        guard let anchor = navigation.anchor(
            for: navigation.world,
            in: cards.map(\.recipe)
        ), let index = cards.firstIndex(where: { $0.id == anchor.recipeID }) else {
            return 0
        }
        return index
    }
}

enum DeckNavigator {
    static func destination(
        from index: Int,
        translation: CGSize,
        predictedTranslation: CGSize,
        cardCount: Int
    ) -> Int {
        guard cardCount > 0 else { return 0 }
        guard abs(translation.height) > abs(translation.width) else {
            return index
        }
        if predictedTranslation.height <= -KartaDesign.deck.swipeThreshold {
            return min(index + 1, cardCount - 1)
        }
        if predictedTranslation.height >= KartaDesign.deck.swipeThreshold {
            return max(index - 1, 0)
        }
        return index
    }
}
