import Foundation

/// An ingredient used by a cooking step, identified by the recipe ingredient's
/// stable id and carrying the amount used at that step.
public struct StepIngredient: Codable, Equatable, Sendable {
    public let ingredientID: String
    public let quantity: String

    public init(ingredientID: String, quantity: String) {
        self.ingredientID = ingredientID
        self.quantity = quantity
    }
}

/// A single self-contained cooking step: instruction plus, optionally, the
/// exact ingredients + quantities that step needs (so the cook never scrolls
/// back).
public struct CookingStep: Codable, Equatable, Sendable, ExpressibleByStringLiteral {
    public let text: String
    public let ingredients: [StepIngredient]
    /// Optional countdown for a timed action ("simmer 10 min" → 600), in seconds.
    public let timerSeconds: Int?
    /// Optional reference to a reusable technique clip, by id. Steps with no
    /// useful clip stay text-only. The clip itself lives in a shared library so
    /// many recipes reference the same clip without duplicating it.
    public let clipID: String?

    public init(
        text: String,
        ingredients: [StepIngredient] = [],
        timerSeconds: Int? = nil,
        clipID: String? = nil
    ) {
        self.text = text
        self.ingredients = ingredients
        self.timerSeconds = timerSeconds
        self.clipID = clipID
    }

    /// A string literal is a text-only step — keeps call sites and seed data terse.
    public init(stringLiteral value: String) {
        self.init(text: value)
    }

    private enum CodingKeys: String, CodingKey {
        case text, ingredients, timerSeconds, clipID
    }

    /// Decodes either a bare string (text-only step) or a full object, so the
    /// seed catalog can mix simple and rich steps.
    public init(from decoder: any Decoder) throws {
        if let single = try? decoder.singleValueContainer(),
           let text = try? single.decode(String.self) {
            self.init(text: text)
            return
        }
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            text: try c.decode(String.self, forKey: .text),
            ingredients: try c.decodeIfPresent([StepIngredient].self, forKey: .ingredients) ?? [],
            timerSeconds: try c.decodeIfPresent(Int.self, forKey: .timerSeconds),
            clipID: try c.decodeIfPresent(String.self, forKey: .clipID)
        )
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

extension Recipe {
    /// Open cooking mode for this recipe: a fresh `CookingSession` over its own
    /// structured steps. This is the seam between the static recipe and the
    /// runtime cooking state machine.
    public func cookingSession(startedAt: TimeInterval = 0) -> CookingSession {
        CookingSession(
            recipeID: id,
            steps: steps,
            declaredDuration: TimeInterval(totalMinutes) * 60,
            startedAt: startedAt
        )
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
    /// True when emitted by the session inference rather than an explicit tap.
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
/// success signal (`cooked`), which may be explicit or inferred from the complete journey.
public struct CookingSession: Equatable, Sendable {
    public let recipeID: String
    public let steps: [CookingStep]
    /// The recipe's declared preparation time, in seconds.
    public let declaredDuration: TimeInterval
    /// The injected start time used to measure this session deterministically.
    public let startedAt: TimeInterval

    public private(set) var currentIndex: Int
    public private(set) var isExited: Bool
    /// The emitted success signal once the cook responds (or is inferred), else `nil`.
    public private(set) var cookedEvent: CookedEvent?
    /// Running timers keyed by step index, so a timer survives navigating away
    /// from and back to its step.
    public private(set) var timers: [Int: StepTimer]
    /// The furthest step reached during the session. Going back does not erase
    /// evidence of the journey.
    private(set) var furthestIndex: Int
    /// The first injected time at which the session reached the last step.
    private(set) var lastStepReachedAt: TimeInterval?

    init(
        recipeID: String,
        steps: [CookingStep],
        declaredDuration: TimeInterval,
        startedAt: TimeInterval,
        currentIndex: Int,
        isExited: Bool,
        cookedEvent: CookedEvent?,
        timers: [Int: StepTimer],
        furthestIndex: Int,
        lastStepReachedAt: TimeInterval?
    ) {
        self.recipeID = recipeID
        self.steps = steps
        self.declaredDuration = declaredDuration
        self.startedAt = startedAt
        self.currentIndex = currentIndex
        self.isExited = isExited
        self.cookedEvent = cookedEvent
        self.timers = timers
        self.furthestIndex = furthestIndex
        self.lastStepReachedAt = lastStepReachedAt
    }

    public init(
        recipeID: String,
        steps: [CookingStep],
        declaredDuration: TimeInterval = 0,
        startedAt: TimeInterval = 0
    ) {
        self.init(
            recipeID: recipeID,
            steps: steps,
            declaredDuration: declaredDuration,
            startedAt: startedAt,
            currentIndex: 0,
            isExited: false,
            cookedEvent: nil,
            timers: [:],
            furthestIndex: 0,
            lastStepReachedAt: nil
        )
    }

    /// The step currently shown, or `nil` if there are no steps.
    public var currentStep: CookingStep? {
        steps.indices.contains(currentIndex) ? steps[currentIndex] : nil
    }

    /// Whether the cook is on the final step.
    public var isOnLastStep: Bool {
        !steps.isEmpty && currentIndex == steps.count - 1
    }

    /// How far the session progressed through the ordered steps, from zero to
    /// one. A one-step recipe has no journey to measure.
    public var stepProgress: Double {
        guard steps.count > 1 else { return 0 }
        return Double(furthestIndex) / Double(steps.count - 1)
    }

    /// Elapsed session time at an injected clock value, never negative.
    public func sessionDuration(at now: TimeInterval) -> TimeInterval {
        max(now - startedAt, 0)
    }

    /// Whether the "How did it turn out?" prompt should be shown. An inferred
    /// cook leaves the prompt open so an explicit outcome can enrich it.
    public var showsOutcomePrompt: Bool {
        isOnLastStep && !isExited && (cookedEvent?.wasInferred ?? true)
    }

    /// Record the cook's response to the outcome prompt. Only valid on the last
    /// step; repeated explicit responses are ignored, while an inferred event
    /// is enriched in place. Returns the new or updated event.
    @discardableResult
    public mutating func respond(_ outcome: CookOutcome) -> CookedEvent? {
        guard isOnLastStep, !isExited else { return nil }
        guard cookedEvent?.wasInferred ?? true else { return nil }
        let event = CookedEvent(recipeID: recipeID, outcome: outcome, wasInferred: false)
        cookedEvent = event
        return event
    }

    /// Advance to the next step (swipe-right). Clamps at the last step.
    public mutating func next() {
        advanceToNextStep(at: nil)
    }

    /// Advance to the next step and record the injected time when the last step
    /// is reached for the first time. Clamps at the last step.
    public mutating func next(at now: TimeInterval) {
        advanceToNextStep(at: now)
    }

    private mutating func advanceToNextStep(at now: TimeInterval?) {
        guard !isExited else { return }
        let previousIndex = currentIndex
        currentIndex = min(currentIndex + 1, max(steps.count - 1, 0))
        furthestIndex = max(furthestIndex, currentIndex)
        if previousIndex != currentIndex,
           currentIndex == steps.count - 1,
           lastStepReachedAt == nil {
            lastStepReachedAt = now
        }
    }

    /// Go back to the previous step (swipe-left). Clamps at the first step.
    public mutating func previous() {
        guard !isExited else { return }
        currentIndex = max(currentIndex - 1, 0)
    }

    /// A session must account for at least this fraction of the recipe's
    /// declared time before it can be considered a probable cook.
    public static let probablyCookedMinimumDurationRatio: Double = 0.25

    /// Infer a cook from the complete session rather than time spent on the
    /// final step. The session must have traversed a real multi-step journey, started
    /// a declared timer when the recipe has one, and taken long enough to reach
    /// the final step relative to the recipe's declared time. Time spent idle on
    /// the final step does not count. Won't override an explicit response and
    /// is ignored after exit.
    @discardableResult
    public mutating func inferProbablyCooked(at now: TimeInterval) -> CookedEvent? {
        let declaredTimerSteps = steps.indices.filter { steps[$0].timerSeconds != nil }
        let startedDeclaredTimer = declaredTimerSteps.isEmpty || declaredTimerSteps.contains { timers[$0] != nil }
        let lastedLongEnough = lastStepReachedAt.map { reachedAt in
            now >= reachedAt
                && declaredDuration > 0
                && sessionDuration(at: reachedAt) >= declaredDuration * Self.probablyCookedMinimumDurationRatio
        } ?? false

        guard isOnLastStep,
              !isExited,
              cookedEvent == nil,
              stepProgress >= 1,
              startedDeclaredTimer,
              lastedLongEnough
        else { return nil }

        let event = CookedEvent(recipeID: recipeID, outcome: nil, wasInferred: true)
        cookedEvent = event
        return event
    }

    // MARK: - In-step timers

    /// Start the current step's timer at `now`, if that step declares one.
    /// Starting a timer after exit is ignored; timers already running continue
    /// to be readable.
    public mutating func startTimer(now: TimeInterval) {
        guard !isExited, let seconds = currentStep?.timerSeconds else { return }
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
