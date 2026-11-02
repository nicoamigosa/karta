import Foundation
import KartaCore

public struct LeftoversToast: Equatable, Sendable {
    public let recipeID: String
    public let ideaCount: Int
    public let title: String
    public let line: String
    public var buttonTitle: String { LeftoversCopy.seeButtonTitle }
    /// The shell sends closeLeftoversToast(.dismissed) on timeout, swipe or accessibility dismissal.
    public let duration: TimeInterval = 5
}

extension KartaState {
    /// Shares the For You toast slot with recipe-gone, which always wins.
    public var leftoversToast: LeftoversToast? {
        guard recipeGoneNotice == nil, navigation.world == .forYou,
              navigation.routes.isEmpty else { return nil }
        return pendingLeftoversToast
    }
}

extension KartaReducer {
    static func offerLeftoversToast(_ state: inout KartaState, recipes: [Recipe], now: Date) {
        guard state.recipeGoneNotice == nil, let session = state.session, session.isExited,
              let event = session.cookedEvent, !event.wasInferred,
              let source = recipes.first(where: { $0.id == event.recipeID }) else { return }
        let entry = CookEntry(recipeID: source.id, date: now)
        // Count only ideas that reuse this cook, not ideas left by some older cook.
        let ideas = state.leftoversFeed(recipes: recipes, clock: ToastClock(now: now)).recipes.filter {
            !PurchasePolicy.reusedIngredients(in: $0, recipes: recipes, cooks: [entry], now: now,
                intolerances: state.safetyProfile.intolerances).isEmpty
        }
        guard !ideas.isEmpty, state.leftoversToastHistory.offer(recipeID: source.id) else { return }
        let ingredients = PurchasePolicy.reusedIngredients(in: source, recipes: recipes, cooks: [entry], now: now,
            intolerances: state.safetyProfile.intolerances).map(\.ingredient)
        state.pendingLeftoversToast = LeftoversCopy.toast(recipe: source, count: ideas.count, ingredients: ingredients)
    }
}

private struct ToastClock: KartaClock { let now: Date }
