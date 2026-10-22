import Foundation
import KartaCore

/// Cierre follows the final Paso and has no Paso content of its own.
public struct CookingFinishPresentation: Equatable, Sendable {
    public let recipeName: String
    public let photo: MediaReference
    public let outcome: Outcome
    public let progress: [CookingStepPresentation.ProgressSegment]

    public enum Outcome: Equatable, Sendable {
        case asking
        case answered(CookOutcome)
    }

    fileprivate init(recipe: Recipe, session: CookingSession, now: TimeInterval) {
        recipeName = recipe.name
        photo = recipe.heroPhoto
        if let event = session.cookedEvent, !event.wasInferred, let answer = event.outcome {
            outcome = .answered(answer)
        } else {
            outcome = .asking
        }
        progress = session.steps.indices.map { index in
            let timer = session.timers[index].map { startedTimer in
                startedTimer.hasFired(at: now)
                    ? CookingStepPresentation.ProgressSegment.TimerState.finished
                    : .running(remainingLabel: countdownLabel(startedTimer.remaining(at: now)))
            }
            return CookingStepPresentation.ProgressSegment(stepIndex: index, state: .done, timer: timer)
        }
    }
}

extension KartaState {
    public func cookingFinishPresentation(for recipe: Recipe, now: TimeInterval) -> CookingFinishPresentation? {
        guard let session, !session.isExited, session.isOnFinish,
              session.recipeID == recipe.id, canOpenRecipe(recipe) else { return nil }
        return CookingFinishPresentation(recipe: recipe, session: session, now: now)
    }
}

extension KartaStore {
    public func cookingFinishPresentation(for recipe: Recipe, now: TimeInterval) -> CookingFinishPresentation? {
        state.cookingFinishPresentation(for: recipe, now: now)
    }
}
