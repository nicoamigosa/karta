import Foundation
import KartaCore

/// Cierre follows the final Paso and has no Paso content of its own.
public struct CookingFinishPresentation: Equatable, Sendable {
    public let recipeName: String
    public let photo: MediaReference
    /// Non-nil only while the finish card offers Share.
    public let sharePayload: SharePayload?
    public let outcome: Outcome
    public let progress: [CookingStepPresentation.ProgressSegment]

    public enum Outcome: Equatable, Sendable {
        case asking
        case answered(CookOutcome)
    }

    fileprivate init(recipe: Recipe, session: CookingSession, now: TimeInterval, sharePayload: SharePayload?) {
        self.sharePayload = sharePayload
        recipeName = recipe.name
        photo = recipe.heroPhoto
        if let event = session.cookedEvent, !event.wasInferred, let answer = event.outcome {
            outcome = .answered(answer)
        } else {
            outcome = .asking
        }
        progress = session.steps.indices.map { index in
            let timer = session.timers[index].map {
                CookingStepPresentation.ProgressSegment.TimerState($0, now: now)
            }
            return CookingStepPresentation.ProgressSegment(stepIndex: index, state: .done, timer: timer)
        }
    }
}

extension KartaState {
    public func cookingFinishPresentation(for recipe: Recipe, now: TimeInterval) -> CookingFinishPresentation? {
        guard let session, !session.isExited, session.isOnFinish,
              session.recipeID == recipe.id, canOpenRecipe(recipe) else { return nil }
        let payload = shareCardHistory.offersCard(for: session.cookedEvent)
            ? RecipeShare(baseURL: shareBaseURL).payload(for: recipe) : nil
        return CookingFinishPresentation(recipe: recipe, session: session, now: now, sharePayload: payload)
    }
}

extension KartaStore {
    public func cookingFinishPresentation(for recipe: Recipe, now: TimeInterval) -> CookingFinishPresentation? {
        state.cookingFinishPresentation(for: recipe, now: now)
    }
}
