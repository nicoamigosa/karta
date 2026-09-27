import CoreGraphics
import KartaCore

struct FeedDeckCard: Identifiable, Equatable {
    let recipe: Recipe
    var alreadySeen: Bool

    var id: String { recipe.id }

    static func cards(in feed: Feed) -> [FeedDeckCard] {
        feed.newRecipes.map { FeedDeckCard(recipe: $0, alreadySeen: false) }
            + feed.alreadySeenRecipes.map { FeedDeckCard(recipe: $0, alreadySeen: true) }
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
