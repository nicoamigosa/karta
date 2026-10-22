import CoreGraphics
import Foundation
import KartaCore
import KartaPresentation

/// A navigation intent inside the cooking session, produced by gestures and
/// resolved into store actions by the view. The transitions themselves live in
/// `CookingSession` — the shell only reports which gesture happened.
enum CookingCommand: Equatable {
    case next
    case previous
}

/// The pure decision behind a drag in cooking mode: horizontal swipes move
/// between Pasos (left = next, right = previous, confirmed 2026-10-19).
/// There is no vertical gesture in the session — leaving is only ever the
/// ✕ button, which asks first — so vertical swipes are ignored.
enum CookingGestureDecision {
    static func command(
        translation: CGSize,
        predictedTranslation: CGSize
    ) -> CookingCommand? {
        let width = predictedTranslation.width
        let height = predictedTranslation.height

        guard abs(width) > abs(height),
              abs(width) >= KartaDesign.cooking.swipeThreshold
        else {
            return nil
        }
        return width < 0 ? .next : .previous
    }
}

/// The pure decision behind a tap in cooking mode: the left half of the card
/// goes back a Paso, the right half advances. Buttons (play, timer, outcome,
/// ✕) sit above the tap surface so their taps never navigate.
enum CookingTapDecision {
    static func command(locationX: CGFloat, width: CGFloat) -> CookingCommand? {
        guard width > 0 else { return nil }
        return locationX < width / 2 ? .previous : .next
    }
}

/// The pure decision behind a Paso settling on screen: which store actions the
/// shell reports. Reaching the final Paso asks the session itself whether the
/// journey already counts as a probable cook — the view adds no dwell timer or
/// inference of its own (ADR 0008). Timers are a separate slice: starting one
/// requires an explicit action from the cook, never a step arrival.
enum CookingStepArrival {
    static func actions(
        for step: CookingStep,
        isLastStep: Bool,
        now: TimeInterval
    ) -> [KartaAction] {
        guard isLastStep else { return [] }
        return [.inferProbablyCooked(now: now)]
    }
}

/// The pure decision behind the cooking overlay: which recipe the active
/// session renders, if the session is still running. An exited session leaves
/// the overlay hidden even while its result remains in the store.
enum CookingRoute {
    static func recipe(
        for session: CookingSession?,
        in recipes: [Recipe]
    ) -> Recipe? {
        guard let session, !session.isExited else { return nil }
        return recipes.first { $0.id == session.recipeID }
    }
}
