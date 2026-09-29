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
    case exit
}

/// The pure decision behind a drag in cooking mode: horizontal swipes move
/// between Pasos (right = next, left = previous), a downward swipe exits.
/// Upward swipes and sub-threshold gestures are ignored.
enum CookingGestureDecision {
    static func command(
        translation: CGSize,
        predictedTranslation: CGSize
    ) -> CookingCommand? {
        let width = predictedTranslation.width
        let height = predictedTranslation.height

        if height >= KartaDesign.cooking.swipeThreshold,
           height > abs(width) {
            return .exit
        }
        guard abs(width) > abs(height),
              abs(width) >= KartaDesign.cooking.swipeThreshold
        else {
            return nil
        }
        return width > 0 ? .next : .previous
    }
}

/// The pure decision behind a tap in cooking mode: the left half of the screen
/// goes back a Paso, the right half advances. Outcome buttons sit above the
/// tap surface so prompt taps never become navigation.
enum CookingTapDecision {
    static func command(locationX: CGFloat, width: CGFloat) -> CookingCommand? {
        guard width > 0 else { return nil }
        return locationX < width / 2 ? .previous : .next
    }
}

/// A step ingredient resolved to what the cook reads: the ingredient's display
/// name plus the step-specific quantity.
struct CookingIngredientRow: Equatable {
    let name: String
    let quantity: String
    let isOptional: Bool
}

/// Resolves a Paso's ingredient references (ids + step quantities) against the
/// recipe's visible ingredients — the same safety-filtered projection the
/// Card reverse consumes, so a hidden optional ingredient can never appear.
enum CookingStepIngredients {
    static func rows(
        for step: CookingStep,
        in recipe: Recipe,
        intolerances: Set<Allergen>
    ) -> [CookingIngredientRow] {
        let visible = Dictionary(
            uniqueKeysWithValues: recipe.visibleIngredients(for: intolerances)
                .map { ($0.id, $0) }
        )
        return step.ingredients.compactMap { reference in
            guard let ingredient = visible[reference.ingredientID] else { return nil }
            return CookingIngredientRow(
                name: ingredient.name,
                quantity: reference.quantity,
                isOptional: ingredient.isOptional
            )
        }
    }
}

/// The pure decision behind a Paso settling on screen: which store actions the
/// shell reports. A Paso declaring a timer gets it started (the countdown is
/// rendered by a later slice); reaching the final Paso asks the session itself
/// whether the journey already counts as a probable cook — the view adds no
/// dwell timer or inference of its own (ADR 0008).
enum CookingStepArrival {
    static func actions(
        for step: CookingStep,
        isLastStep: Bool,
        now: TimeInterval
    ) -> [KartaAction] {
        var actions: [KartaAction] = []
        if step.timerSeconds != nil {
            actions.append(.startTimer(now: now))
        }
        if isLastStep {
            actions.append(.inferProbablyCooked(now: now))
        }
        return actions
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
