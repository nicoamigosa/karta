import Foundation

/// A single self-contained cooking step: instruction plus, optionally, the exact
/// ingredient + quantity that step needs (so the cook never scrolls back).
public struct CookingStep: Equatable, Sendable {
    public let text: String
    public let ingredient: Ingredient?
    /// Optional countdown for a timed action ("simmer 10 min" → 600), in seconds.
    public let timerSeconds: Int?
    /// Optional reference to a reusable technique clip, by id. Steps with no
    /// useful clip stay text-only. The clip itself lives in a shared library so
    /// many recipes reference the same clip without duplicating it.
    public let clipID: String?

    public init(
        text: String,
        ingredient: Ingredient? = nil,
        timerSeconds: Int? = nil,
        clipID: String? = nil
    ) {
        self.text = text
        self.ingredient = ingredient
        self.timerSeconds = timerSeconds
        self.clipID = clipID
    }
}

/// A running (or finished) in-step timer: when it was started and for how long.
/// Pure data — elapsed/remaining are computed against an injected clock.
public struct StepTimer: Equatable, Sendable {
    public let startedAt: TimeInterval
    public let duration: TimeInterval

    public init(startedAt: TimeInterval, duration: TimeInterval) {
        self.startedAt = startedAt
        self.duration = duration
    }

    /// Seconds left at `now`, floored at zero.
    public func remaining(at now: TimeInterval) -> TimeInterval {
        max(duration - (now - startedAt), 0)
    }

    /// Whether the countdown has reached zero by `now`.
    public func hasFired(at now: TimeInterval) -> Bool {
        now - startedAt >= duration
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
    /// Running timers keyed by step index, so a timer survives navigating away
    /// from and back to its step.
    public private(set) var timers: [Int: StepTimer]

    public init(recipeID: String, steps: [CookingStep]) {
        self.recipeID = recipeID
        self.steps = steps
        self.currentIndex = 0
        self.isExited = false
        self.cookedEvent = nil
        self.timers = [:]
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

    // MARK: - In-step timers

    /// Start the current step's timer at `now`, if that step declares one.
    public mutating func startTimer(now: TimeInterval) {
        guard let seconds = currentStep?.timerSeconds else { return }
        timers[currentIndex] = StepTimer(startedAt: now, duration: TimeInterval(seconds))
    }

    /// Seconds left on the current step's running timer at `now`, or `nil` if none.
    public func currentStepTimerRemaining(at now: TimeInterval) -> TimeInterval? {
        timers[currentIndex]?.remaining(at: now)
    }

    /// Whether the current step's running timer has fired by `now` (false if none).
    public func currentStepTimerHasFired(at now: TimeInterval) -> Bool {
        timers[currentIndex]?.hasFired(at: now) ?? false
    }

    /// Leave cooking mode (swipe-down). Terminal: further navigation is ignored.
    public mutating func exit() {
        isExited = true
    }
}
