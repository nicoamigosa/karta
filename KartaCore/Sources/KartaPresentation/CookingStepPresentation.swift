import Foundation
import KartaCore

/// All content for the active Paso, projected from the store's session.
public struct CookingStepPresentation: Equatable, Sendable {
    public let summary: String
    public let detail: String
    public let photo: MediaReference?
    public let clip: Clip?
    /// Countdown display, initially the declared duration, then the remaining time.
    public let timerLabel: String?
    public let ingredientRows: [IngredientRow]
    @available(*, deprecated, message: "Variant E uses Cierre after the last Paso; Up next is no longer rendered.")
    public let upNext: UpNext?
    public let progress: [ProgressSegment]

    public struct ProgressSegment: Equatable, Sendable {
        /// Index in the session's visible steps; also the timer's navigation target.
        public let stepIndex: Int
        public let state: State
        public let timer: TimerState?

        public enum State: Equatable, Sendable {
            case done, current, upcoming
        }

        public enum TimerState: Equatable, Sendable {
            case running(remainingLabel: String)
            case finished
        }
    }

    @available(*, deprecated, message: "Variant E no longer renders Up next.")
    public struct UpNext: Equatable, Sendable {
        public let summary: String
        public let photo: MediaReference?
    }

    public struct IngredientRow: Equatable, Sendable {
        public let ingredientID: String
        public let quantity: String
        public let name: String
    }

    public struct Clip: Equatable, Sendable {
        public let id: String
        public let name: String
        public let lengthLabel: String
        public let source: MediaReference
    }

    fileprivate init(
        step: CookingStep,
        session: CookingSession,
        recipe: Recipe,
        clips: TechniqueClipLibrary,
        intolerances: Set<Allergen>,
        now: TimeInterval
    ) {
        progress = session.steps.indices.map { index in
            let timer: ProgressSegment.TimerState?
            if index != session.currentIndex, let startedTimer = session.timers[index] {
                timer = startedTimer.hasFired(at: now)
                    ? .finished
                    : .running(remainingLabel: countdownLabel(startedTimer.remaining(at: now)))
            } else {
                timer = nil
            }
            return ProgressSegment(
                stepIndex: index,
                state: index == session.currentIndex ? .current : (index < session.currentIndex ? .done : .upcoming),
                timer: timer
            )
        }
        let nextIndex = session.currentIndex + 1
        upNext = session.steps.indices.contains(nextIndex)
            ? UpNext(summary: session.steps[nextIndex].summary, photo: session.steps[nextIndex].photo)
            : nil
        summary = step.summary
        detail = step.detail
        photo = step.photo
        clip = clips.clip(for: step).map {
            Clip(id: $0.id, name: $0.title,
                 lengthLabel: DurationText.shortFormat(seconds: $0.seconds), source: $0.source)
        }
        timerLabel = session.currentStepTimerRemaining(at: now).map(countdownLabel)
            ?? step.timerSeconds.map { countdownLabel(TimeInterval($0)) }
        let ingredients = recipe.visibleIngredients(for: intolerances)
        ingredientRows = step.ingredients.compactMap { use in
            guard let ingredient = ingredients.first(where: { $0.id == use.ingredientID }) else { return nil }
            return IngredientRow(ingredientID: ingredient.id, quantity: use.quantity, name: ingredient.name)
        }
    }
}

/// Round up fractional seconds so a running timer does not display zero early.
func countdownLabel(_ remaining: TimeInterval) -> String {
    let seconds = Int(ceil(max(remaining, 0)))
    let minutes = seconds / 60
    let remainder = seconds % 60
    return "\(minutes):\(remainder < 10 ? "0" : "")\(remainder)"
}

extension KartaState {
    public func cookingStepPresentation(
        for recipe: Recipe,
        clips: TechniqueClipLibrary,
        now: TimeInterval
    ) -> CookingStepPresentation? {
        guard let session, !session.isExited, !session.isOnFinish, session.recipeID == recipe.id,
              let step = session.currentStep,
              canOpenRecipe(recipe) else { return nil }
        return CookingStepPresentation(
            step: step, session: session, recipe: recipe, clips: clips,
            intolerances: safetyProfile.intolerances, now: now
        )
    }
}

extension KartaStore {
    public func cookingStepPresentation(
        for recipe: Recipe,
        clips: TechniqueClipLibrary,
        now: TimeInterval
    ) -> CookingStepPresentation? {
        state.cookingStepPresentation(for: recipe, clips: clips, now: now)
    }
}
