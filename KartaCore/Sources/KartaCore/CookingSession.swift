import Foundation

/// A single self-contained cooking step: instruction plus, optionally, the exact
/// ingredient + quantity that step needs (so the cook never scrolls back).
public struct CookingStep: Equatable, Sendable {
    public let text: String
    public let ingredient: Ingredient?

    public init(text: String, ingredient: Ingredient? = nil) {
        self.text = text
        self.ingredient = ingredient
    }
}

/// How a finished cook turned out, captured by the "How did it turn out?" prompt.
public enum CookOutcome: String, Equatable, Sendable {
    case thumbsUp   // 👍
    case thumbsDown // 👎
    case photo      // 📷
}

/// The core success signal: the user reached the end of a recipe and (explicitly
/// or by inference) cooked it.
public struct CookedEvent: Equatable, Sendable {
    public let recipeID: String
    public let outcome: CookOutcome?
    /// True when emitted by the "probably cooked" dwell inference rather than a tap.
    public let wasInferred: Bool

    public init(recipeID: String, outcome: CookOutcome?, wasInferred: Bool) {
        self.recipeID = recipeID
        self.outcome = outcome
        self.wasInferred = wasInferred
    }
}

/// Step-by-step cooking mode modeled as a UI-independent state machine.
///
/// The session walks an ordered list of `CookingStep`s. Navigation clamps at the
/// boundaries; exiting is terminal. Reaching the last step is the gateway to the
/// success signal (`cooked`), handled in later slices.
public struct CookingSession: Equatable, Sendable {
    public let recipeID: String
    public let steps: [CookingStep]

    public private(set) var currentIndex: Int
    public private(set) var isExited: Bool
    /// The emitted success signal once the cook responds (or is inferred), else `nil`.
    public private(set) var cookedEvent: CookedEvent?

    public init(recipeID: String, steps: [CookingStep]) {
        self.recipeID = recipeID
        self.steps = steps
        self.currentIndex = 0
        self.isExited = false
        self.cookedEvent = nil
    }

    /// The step currently shown, or `nil` if there are no steps.
    public var currentStep: CookingStep? {
        steps.indices.contains(currentIndex) ? steps[currentIndex] : nil
    }

    /// Whether the cook is on the final step.
    public var isOnLastStep: Bool {
        !steps.isEmpty && currentIndex == steps.count - 1
    }

    /// Whether the "How did it turn out?" prompt should be shown.
    public var showsOutcomePrompt: Bool {
        isOnLastStep && !isExited
    }

    /// Record the cook's response to the outcome prompt. Only valid on the last
    /// step; returns the emitted `cooked` event (or `nil` if not applicable).
    @discardableResult
    public mutating func respond(_ outcome: CookOutcome) -> CookedEvent? {
        guard isOnLastStep, !isExited else { return nil }
        let event = CookedEvent(recipeID: recipeID, outcome: outcome, wasInferred: false)
        cookedEvent = event
        return event
    }

    /// Advance to the next step (swipe-right). Clamps at the last step.
    public mutating func next() {
        guard !isExited else { return }
        currentIndex = min(currentIndex + 1, max(steps.count - 1, 0))
    }

    /// Go back to the previous step (swipe-left). Clamps at the first step.
    public mutating func previous() {
        guard !isExited else { return }
        currentIndex = max(currentIndex - 1, 0)
    }

    /// Dwell long enough on the last step (without tapping) to infer the cook
    /// probably finished. Default threshold: 20s. Won't override an explicit
    /// response and only fires on the last step.
    public static let probablyCookedDwellSeconds: TimeInterval = 20

    @discardableResult
    public mutating func inferProbablyCooked(
        dwellSeconds: TimeInterval,
        threshold: TimeInterval = CookingSession.probablyCookedDwellSeconds
    ) -> CookedEvent? {
        guard isOnLastStep, cookedEvent == nil, dwellSeconds >= threshold else { return nil }
        let event = CookedEvent(recipeID: recipeID, outcome: nil, wasInferred: true)
        cookedEvent = event
        return event
    }

    /// Leave cooking mode (swipe-down). Terminal: further navigation is ignored.
    public mutating func exit() {
        isExited = true
    }
}
