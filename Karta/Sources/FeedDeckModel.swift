import CoreGraphics
import Foundation
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

/// The pure decision behind a tap on the front Card: which store actions the
/// Apertura produces. Sending these is what opens the recipe detail.
enum CardOpening {
    static func actions(recipeID: String, at date: Date) -> [KartaAction] {
        [
            .recordOpen(recipeID: recipeID, at: date),
            .pushRoute(.recipeDetail(recipeID: recipeID))
        ]
    }
}

/// The deck's rebuild key (ADR 0009): the Mundo plus the effective filters.
/// The reducer discards the session anchors whenever `effectiveFeedFilters`
/// changes — an applied draft or a declared Intolerancia — so a new identity
/// rebuilds the deck, which then reads the discarded anchor and starts at
/// the top of the new feed.
enum FeedDeckIdentity {
    static func key(world: World, filters: FeedFilters) -> String {
        [
            world.rawValue,
            Allergen.allCases.filter(filters.intolerances.contains)
                .map(\.rawValue).joined(separator: ","),
            filters.maxMinutes.map(String.init) ?? "-",
            filters.maxDifficulty?.rawValue ?? "-",
            filters.course?.rawValue ?? "-",
            filters.diet?.rawValue ?? "-",
            PracticalTag.allCases.filter(filters.practicalTags.contains)
                .map(\.rawValue).joined(separator: ",")
        ].joined(separator: "|")
    }
}

/// The pure decision behind the detail overlay: which recipe the current
/// routes present, if any. The view applies no other rule.
enum RecipeReverseRoute {
    static func recipe(for routes: [Route], in recipes: [Recipe]) -> Recipe? {
        guard case let .recipeDetail(recipeID) = routes.last else { return nil }
        return recipes.first { $0.id == recipeID }
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
