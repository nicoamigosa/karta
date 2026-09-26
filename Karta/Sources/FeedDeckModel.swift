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
        predictedTranslation: CGFloat,
        cardCount: Int
    ) -> Int {
        guard cardCount > 0 else { return 0 }
        if predictedTranslation <= -KartaDesign.deck.swipeThreshold {
            return min(index + 1, cardCount - 1)
        }
        if predictedTranslation >= KartaDesign.deck.swipeThreshold {
            return max(index - 1, 0)
        }
        return index
    }
}
